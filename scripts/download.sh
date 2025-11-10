#!/bin/bash
# download.sh - Download all generated images from RunPod

set -e

# Load configuration
if [ ! -f "config.env" ]; then
    echo "Error: config.env not found!"
    exit 1
fi

source config.env

# Build SCP command
SCP_CMD="scp"
if [ ! -z "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
    SCP_CMD="$SCP_CMD -i $SSH_KEY"
fi
SCP_CMD="$SCP_CMD -P $RUNPOD_PORT"

SSH_HOST="${RUNPOD_USER}@${RUNPOD_HOST}"

echo "=== Downloading Images from RunPod ==="
echo ""

# Create outputs directory
mkdir -p outputs

# Download all images
echo "Downloading from $SSH_HOST:/workspace/outputs/ ..."
$SCP_CMD "$SSH_HOST:/workspace/outputs/*.jpg" outputs/ 2>/dev/null || {
    echo "No images found or connection failed"
    exit 1
}

echo "✓ Download complete"
echo ""

# Show downloaded files
echo "Downloaded images:"
ls -lh outputs/*.jpg

echo ""
echo "Images saved to: outputs/"
