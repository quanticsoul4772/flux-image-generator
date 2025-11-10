#!/bin/bash
# generate.sh - Generate images using FLUX.1 on RunPod from WSL

set -e

# Load configuration
if [ ! -f "config.env" ]; then
    echo "Error: config.env not found!"
    exit 1
fi

source config.env

# Build SSH/SCP commands
SSH_CMD="ssh"
SCP_CMD="scp"
if [ ! -z "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY"
    SCP_CMD="$SCP_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD -p $RUNPOD_PORT"
SCP_CMD="$SCP_CMD -P $RUNPOD_PORT"

SSH_HOST="${RUNPOD_USER}@${RUNPOD_HOST}"

# Default parameters
STEPS=${DEFAULT_STEPS:-40}
WIDTH=${DEFAULT_WIDTH:-1024}
HEIGHT=${DEFAULT_HEIGHT:-1024}
GUIDANCE=${DEFAULT_GUIDANCE:-7.5}
BATCH_MODE=false
BATCH_FILE=""
AUTO_DOWNLOAD=true

# Parse arguments
PROMPT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --batch)
            BATCH_MODE=true
            BATCH_FILE="$2"
            shift 2
            ;;
        --steps)
            STEPS="$2"
            shift 2
            ;;
        --width)
            WIDTH="$2"
            shift 2
            ;;
        --height)
            HEIGHT="$2"
            shift 2
            ;;
        --guidance)
            GUIDANCE="$2"
            shift 2
            ;;
        --no-download)
            AUTO_DOWNLOAD=false
            shift
            ;;
        --help|-h)
            echo "Usage: bash generate.sh \"prompt\" [options]"
            echo "       bash generate.sh --batch prompts.txt [options]"
            echo ""
            echo "Options:"
            echo "  --batch FILE      Generate from prompts in FILE (one per line)"
            echo "  --steps N         Number of inference steps (default: $DEFAULT_STEPS)"
            echo "  --width N         Image width (default: $DEFAULT_WIDTH)"
            echo "  --height N        Image height (default: $DEFAULT_HEIGHT)"
            echo "  --guidance N      Guidance scale (default: $DEFAULT_GUIDANCE)"
            echo "  --no-download     Don't auto-download after generation"
            echo "  --help            Show this help"
            echo ""
            echo "Examples:"
            echo "  bash generate.sh \"a serene lake at sunset\""
            echo "  bash generate.sh \"cyberpunk city\" --steps 50 --width 1536 --height 1024"
            echo "  bash generate.sh --batch prompts.txt --steps 30"
            exit 0
            ;;
        *)
            if [ -z "$PROMPT" ]; then
                PROMPT="$1"
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [ "$BATCH_MODE" = false ] && [ -z "$PROMPT" ]; then
    echo "Error: No prompt provided"
    echo "Usage: bash generate.sh \"your prompt\" [options]"
    echo "       bash generate.sh --help for more options"
    exit 1
fi

if [ "$BATCH_MODE" = true ] && [ ! -f "$BATCH_FILE" ]; then
    echo "Error: Batch file not found: $BATCH_FILE"
    exit 1
fi

# Test connection
echo "Connecting to RunPod VM..."
if ! $SSH_CMD $SSH_HOST "echo 'Connected'" &>/dev/null; then
    echo "Error: Cannot connect to RunPod VM"
    echo "Please check config.env and ensure pod is running"
    exit 1
fi

if [ "$BATCH_MODE" = true ]; then
    # Batch mode
    echo "=== Batch Generation Mode ==="
    echo "Reading prompts from: $BATCH_FILE"
    echo ""
    
    # Count prompts
    PROMPT_COUNT=$(grep -c "^" "$BATCH_FILE" || echo "0")
    echo "Found $PROMPT_COUNT prompts"
    echo ""
    
    # Upload batch file to RunPod
    echo "Uploading batch file..."
    $SCP_CMD "$BATCH_FILE" $SSH_HOST:/tmp/batch_prompts.txt
    
    # Create and upload batch generation script
    cat > /tmp/batch_generate.sh << 'BATCH_SCRIPT'
#!/bin/bash
source /workspace/.venv/bin/activate
cd /workspace/scripts

counter=1
while IFS= read -r prompt; do
    [ -z "$prompt" ] && continue
    echo ""
    echo "=== Generating image $counter ==="
    echo "Prompt: $prompt"
    
    python3 generate.py "$prompt" \
        --steps STEPS_PLACEHOLDER \
        --width WIDTH_PLACEHOLDER \
        --height HEIGHT_PLACEHOLDER \
        --guidance GUIDANCE_PLACEHOLDER \
        --output "batch_${counter}.jpg"
    
    counter=$((counter + 1))
done < /tmp/batch_prompts.txt

echo ""
echo "=== Batch generation complete ==="
echo "Generated $((counter - 1)) images in /workspace/outputs/"
BATCH_SCRIPT
    
    # Replace placeholders
    sed -i "s/STEPS_PLACEHOLDER/$STEPS/g" /tmp/batch_generate.sh
    sed -i "s/WIDTH_PLACEHOLDER/$WIDTH/g" /tmp/batch_generate.sh
    sed -i "s/HEIGHT_PLACEHOLDER/$HEIGHT/g" /tmp/batch_generate.sh
    sed -i "s/GUIDANCE_PLACEHOLDER/$GUIDANCE/g" /tmp/batch_generate.sh
    
    # Upload batch script
    $SCP_CMD /tmp/batch_generate.sh $SSH_HOST:/tmp/batch_generate.sh
    
    # Execute batch generation
    echo "Starting batch generation on RunPod..."
    $SSH_CMD $SSH_HOST "chmod +x /tmp/batch_generate.sh && /tmp/batch_generate.sh"
    
    # Clean up
    rm /tmp/batch_generate.sh
else
    # Single prompt mode
    echo "=== Generating Image ==="
    echo "Prompt: $PROMPT"
    echo "Size: ${WIDTH}x${HEIGHT}"
    echo "Steps: $STEPS"
    echo "Guidance: $GUIDANCE"
    echo ""
    
    # Generate image
    $SSH_CMD $SSH_HOST "source /workspace/.venv/bin/activate && cd /workspace/scripts && python3 generate.py \"$PROMPT\" --steps $STEPS --width $WIDTH --height $HEIGHT --guidance $GUIDANCE"
fi

# Download outputs
if [ "$AUTO_DOWNLOAD" = true ]; then
    echo ""
    echo "Downloading generated images..."
    mkdir -p outputs
    
    # Download all new images
    $SCP_CMD "$SSH_HOST:/workspace/outputs/*.jpg" outputs/ 2>/dev/null || echo "No new images to download"
    
    echo "✓ Images downloaded to: outputs/"
    echo ""
    
    # Show generated images
    IMAGE_COUNT=$(ls -1 outputs/*.jpg 2>/dev/null | wc -l)
    if [ $IMAGE_COUNT -gt 0 ]; then
        echo "Generated images:"
        ls -lh outputs/*.jpg | tail -n $IMAGE_COUNT
    fi
fi

echo ""
echo "=== Generation Complete ==="
echo ""
echo "To view images:"
echo "  ls -lh outputs/"
echo ""
echo "To download manually:"
echo "  bash scripts/download.sh"
echo ""
