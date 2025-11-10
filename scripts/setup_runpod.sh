#!/bin/bash
# setup_runpod.sh - Run this script on RunPod VM to set up FLUX.1 environment

set -e  # Exit on any error

echo "=== FLUX.1 [dev] RunPod Setup ==="
echo "This will install dependencies and download the FLUX.1 model (~24GB)"
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Update system packages
log_info "Updating system packages..."
apt-get update -qq

# Install required system packages
log_info "Installing system dependencies..."
apt-get install -y -qq \
    python3.10 \
    python3.10-venv \
    python3-pip \
    git \
    wget \
    curl \
    htop \
    tmux \
    vim

# Check GPU
log_info "Checking GPU availability..."
if ! command -v nvidia-smi &> /dev/null; then
    log_error "nvidia-smi not found! GPU drivers not installed."
    exit 1
fi

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{print int($1/1024)}')
log_info "GPU Memory: ${GPU_MEM}GB"

if [ "$GPU_MEM" -lt 20 ]; then
    log_warn "GPU has less than 20GB VRAM. FLUX.1 may not run properly."
    log_warn "Recommended: 24GB+ VRAM"
fi

# Create workspace structure
log_info "Creating workspace directories..."
mkdir -p /workspace/flux
mkdir -p /workspace/outputs
mkdir -p /workspace/scripts
cd /workspace

# Set up Python virtual environment
log_info "Setting up Python virtual environment..."
if [ ! -d "/workspace/.venv" ]; then
    python3.10 -m venv /workspace/.venv
fi

source /workspace/.venv/bin/activate

# Upgrade pip
log_info "Upgrading pip..."
pip install --quiet --upgrade pip setuptools wheel

# Install PyTorch with CUDA support
log_info "Installing PyTorch with CUDA support..."
pip install --quiet torch torchvision --index-url https://download.pytorch.org/whl/cu121

# Install diffusers and dependencies
log_info "Installing diffusers and dependencies..."
pip install --quiet \
    diffusers[torch] \
    transformers \
    accelerate \
    safetensors \
    sentencepiece \
    protobuf

# Verify CUDA is available
log_info "Verifying CUDA installation..."
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"

# Create the generation script
log_info "Creating generation script..."
cat > /workspace/scripts/generate.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
FLUX.1 [dev] Image Generation Script
Usage: python generate.py "your prompt here" [options]
"""

import os
import sys
import argparse
import torch
from datetime import datetime
from pathlib import Path
from diffusers import FluxPipeline

def main():
    parser = argparse.ArgumentParser(description='Generate images with FLUX.1 [dev]')
    parser.add_argument('prompt', type=str, help='Text prompt for image generation')
    parser.add_argument('--steps', type=int, default=40, help='Number of inference steps (default: 40)')
    parser.add_argument('--width', type=int, default=1024, help='Image width (default: 1024)')
    parser.add_argument('--height', type=int, default=1024, help='Image height (default: 1024)')
    parser.add_argument('--guidance', type=float, default=7.5, help='Guidance scale (default: 7.5)')
    parser.add_argument('--output', type=str, default=None, help='Output filename (default: auto-generated)')
    parser.add_argument('--seed', type=int, default=None, help='Random seed for reproducibility')
    
    args = parser.parse_args()
    
    # Ensure output directory exists
    output_dir = Path("/workspace/outputs")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate output filename if not provided
    if args.output is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        args.output = output_dir / f"flux_{timestamp}.jpg"
    else:
        args.output = output_dir / args.output
    
    print(f"=== FLUX.1 [dev] Image Generation ===")
    print(f"Prompt: {args.prompt}")
    print(f"Size: {args.width}x{args.height}")
    print(f"Steps: {args.steps}")
    print(f"Guidance: {args.guidance}")
    if args.seed:
        print(f"Seed: {args.seed}")
    print(f"Output: {args.output}")
    print()
    
    # Load the model with memory optimization
    print("Loading FLUX.1 [dev] model...")
    print("(Using CPU offloading for 24GB GPU compatibility)")
    
    # Set cache directory
    os.environ['HF_HOME'] = '/workspace/.cache/huggingface'
    
    try:
        pipe = FluxPipeline.from_pretrained(
            "black-forest-labs/FLUX.1-dev",
            torch_dtype=torch.bfloat16,
            cache_dir="/workspace/.cache/huggingface"
        )
        
        # Enable memory optimization for 24GB GPUs
        pipe.enable_model_cpu_offload()
        pipe.enable_sequential_cpu_offload()
        pipe.vae.enable_slicing()
        pipe.vae.enable_tiling()
        
        print("✓ Model loaded successfully")
        print("✓ Memory optimization enabled")
        print()
        
        # Set seed for reproducibility if provided
        if args.seed is not None:
            generator = torch.Generator("cuda").manual_seed(args.seed)
        else:
            generator = None
        
        # Generate image
        print("Generating image...")
        start_time = datetime.now()
        
        result = pipe(
            prompt=args.prompt,
            height=args.height,
            width=args.width,
            num_inference_steps=args.steps,
            guidance_scale=args.guidance,
            generator=generator
        )
        
        image = result.images[0]
        
        # Save image
        image.save(args.output, quality=95)
        
        elapsed = (datetime.now() - start_time).total_seconds()
        print(f"✓ Generation complete in {elapsed:.1f} seconds")
        print(f"✓ Saved to: {args.output}")
        
        # Print file size
        file_size_mb = os.path.getsize(args.output) / (1024 * 1024)
        print(f"✓ File size: {file_size_mb:.2f} MB")
        
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

chmod +x /workspace/scripts/generate.py

# Check if model is already downloaded (persistent volume)
MODEL_PATH="/workspace/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-dev"
if [ -d "$MODEL_PATH" ]; then
    log_info "FLUX.1 model already exists on volume - skipping download!"
    log_info "Model location: $MODEL_PATH"
else
    log_info "Pre-downloading FLUX.1 [dev] model..."
    log_warn "This will download ~24GB. Please be patient (5-15 minutes depending on connection)."
fi

# Only download if not already present
if [ ! -d "$MODEL_PATH" ]; then
    python3 << 'DOWNLOAD_SCRIPT'
import torch
from diffusers import FluxPipeline
import os

print("Starting model download...")
os.makedirs("/workspace/.cache/huggingface", exist_ok=True)

# Set cache directory
os.environ['HF_HOME'] = '/workspace/.cache/huggingface'

try:
    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev",
        torch_dtype=torch.bfloat16,
        cache_dir="/workspace/.cache/huggingface"
    )
    print("✓ Model downloaded successfully!")
    print(f"✓ Model cached in: /workspace/.cache/huggingface")
    
    # Free memory
    del pipe
    torch.cuda.empty_cache()
    
except Exception as e:
    print(f"✗ Error downloading model: {e}")
    exit(1)
DOWNLOAD_SCRIPT
fi

# Create a test script
log_info "Creating test script..."
cat > /workspace/test.sh << 'TEST_SCRIPT'
#!/bin/bash
source /workspace/.venv/bin/activate
cd /workspace/scripts
python3 generate.py "a serene mountain landscape at sunrise, photorealistic, 4k" --steps 30 --output test_output.jpg
echo ""
echo "Test image saved to: /workspace/outputs/test_output.jpg"
echo "Download it with: scp root@<your-ip>:/workspace/outputs/test_output.jpg ."
TEST_SCRIPT

chmod +x /workspace/test.sh

# Create a convenience alias script
cat > /workspace/generate.sh << 'GEN_SCRIPT'
#!/bin/bash
source /workspace/.venv/bin/activate
cd /workspace/scripts
python3 generate.py "$@"
GEN_SCRIPT

chmod +x /workspace/generate.sh

# Print summary
echo ""
log_info "=== Setup Complete! ==="
echo ""
echo "✓ Python environment: /workspace/.venv"
echo "✓ Generation script: /workspace/scripts/generate.py"
echo "✓ Output directory: /workspace/outputs"
echo "✓ Model cache: /workspace/.cache"
echo ""
echo "Quick Start:"
echo "  1. Test generation:"
echo "     bash /workspace/test.sh"
echo ""
echo "  2. Generate custom image:"
echo "     bash /workspace/generate.sh \"your prompt here\""
echo ""
echo "  3. Download outputs:"
echo "     scp root@<your-ip>:/workspace/outputs/*.jpg ."
echo ""
echo "GPU Info:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader
echo ""
log_info "Ready to generate images! 🎨"
