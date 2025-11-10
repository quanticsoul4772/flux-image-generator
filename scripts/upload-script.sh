#!/bin/bash
# ============================================================================
# Upload generate.py to RunPod
# ============================================================================

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/lib/config.sh"
source ~/flux-image-generator/config.env

echo "Uploading generate.py to RunPod..."

# Create scripts directory if it doesn't exist
if ! ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i "$SSH_KEY" \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY}" \
    "mkdir -p ${WORKSPACE_SCRIPTS} ${WORKSPACE_OUTPUTS}"; then
    echo "ERROR: Failed to create directories on RunPod" >&2
    exit 1
fi

# Upload script
if ! scp -i "$SSH_KEY" -P ${RUNPOD_PORT} \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY}" \
    ~/flux-image-generator/src/generate.py \
    root@${RUNPOD_HOST}:${WORKSPACE_SCRIPTS}/; then
    echo "ERROR: Failed to upload generate.py" >&2
    exit 1
fi

# Make executable
if ! ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i "$SSH_KEY" \
    -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY}" \
    "chmod +x ${WORKSPACE_SCRIPTS}/generate.py"; then
    echo "ERROR: Failed to make generate.py executable" >&2
    exit 1
fi

echo "✓ Upload complete!"
