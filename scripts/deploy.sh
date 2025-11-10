#!/bin/bash
# deploy.sh - Deploy FLUX.1 setup to RunPod VM from WSL

set -e

# Load configuration
if [ ! -f "config.env" ]; then
    echo "Error: config.env not found!"
    echo "Please create config.env with your RunPod connection details."
    exit 1
fi

source config.env

# Check required variables
if [ -z "$RUNPOD_HOST" ] || [ "$RUNPOD_HOST" = "123.45.67.89" ]; then
    echo "Error: RUNPOD_HOST not set in config.env"
    echo "Please update config.env with your RunPod IP address."
    exit 1
fi

if [ -z "$RUNPOD_PORT" ]; then
    echo "Error: RUNPOD_PORT not set in config.env"
    exit 1
fi

if [ -z "$RUNPOD_USER" ]; then
    RUNPOD_USER=root
fi

# Build SSH command
SSH_CMD="ssh"
SCP_CMD="scp"
if [ ! -z "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY"
    SCP_CMD="$SCP_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD -p $RUNPOD_PORT"
SCP_CMD="$SCP_CMD -P $RUNPOD_PORT"

SSH_HOST="${RUNPOD_USER}@${RUNPOD_HOST}"

echo "=== Deploying FLUX.1 to RunPod ==="
echo "Host: $RUNPOD_HOST:$RUNPOD_PORT"
echo ""

# Test connection
echo "Testing SSH connection..."
if ! $SSH_CMD $SSH_HOST "echo 'Connection successful'"; then
    echo "Error: Cannot connect to RunPod VM"
    echo "Please check:"
    echo "  1. Pod is running in RunPod dashboard"
    echo "  2. RUNPOD_HOST and RUNPOD_PORT are correct in config.env"
    echo "  3. SSH port (22) is exposed in RunPod"
    exit 1
fi

echo "✓ SSH connection successful"
echo ""

# Upload setup script
echo "Uploading setup script..."
$SCP_CMD scripts/setup_runpod.sh $SSH_HOST:/tmp/setup_runpod.sh

echo "✓ Setup script uploaded"
echo ""

# Run setup script
echo "Running setup on RunPod VM..."
echo "This will take 10-20 minutes for first-time setup (model download is ~24GB)"
echo ""

$SSH_CMD $SSH_HOST "chmod +x /tmp/setup_runpod.sh && /tmp/setup_runpod.sh"

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Test generation:"
echo "     bash scripts/generate.sh \"a beautiful sunset over mountains\""
echo ""
echo "  2. Generate batch images:"
echo "     bash scripts/generate.sh --batch prompts.txt"
echo ""
echo "  3. SSH into RunPod for manual control:"
echo "     $SSH_CMD $SSH_HOST"
echo ""
