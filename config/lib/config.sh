#!/bin/bash
# ============================================================================
# Shared configuration for FLUX image generator shell scripts
# ============================================================================
# Source this file in scripts to get standardized paths and settings.
#
# Usage:
#   source "$(dirname "$0")/lib/config.sh"
#   # or
#   source ~/flux-image-generator/lib/config.sh
# ============================================================================

# RunPod Paths
# These can be overridden by environment variables for custom deployments
export WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
export WORKSPACE_CACHE="${WORKSPACE_CACHE:-${WORKSPACE_PATH}/.cache}"
export WORKSPACE_VENV="${WORKSPACE_VENV:-${WORKSPACE_PATH}/.venv}"
export WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-${WORKSPACE_PATH}/scripts}"
export WORKSPACE_OUTPUTS="${WORKSPACE_OUTPUTS:-${WORKSPACE_PATH}/outputs}"
export HF_CACHE="${HF_CACHE:-${WORKSPACE_CACHE}/huggingface}"

# SSH Configuration
# Can be overridden by environment variables or config.env
export SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-10}"
export SSH_STRICT_HOST_KEY="${SSH_STRICT_HOST_KEY:-accept-new}"

# Quality Presets (inference steps)
# Match config_defaults.yaml values
export STEPS_FAST="${STEPS_FAST:-4}"
export STEPS_BALANCED="${STEPS_BALANCED:-20}"
export STEPS_QUALITY="${STEPS_QUALITY:-50}"

# Guidance Scale Presets
# Match config_defaults.yaml values
export GUIDANCE_CREATIVE="${GUIDANCE_CREATIVE:-1.5}"
export GUIDANCE_DEFAULT="${GUIDANCE_DEFAULT:-3.5}"
export GUIDANCE_STRICT="${GUIDANCE_STRICT:-5.0}"

# Image Generation Defaults
export DEFAULT_HEIGHT="${DEFAULT_HEIGHT:-1024}"
export DEFAULT_WIDTH="${DEFAULT_WIDTH:-1024}"
export DEFAULT_JPEG_QUALITY="${DEFAULT_JPEG_QUALITY:-95}"

# Resolution Presets
# Common aspect ratios for different use cases
export RESOLUTION_SQUARE_WIDTH=1024
export RESOLUTION_SQUARE_HEIGHT=1024

export RESOLUTION_PORTRAIT_WIDTH=768
export RESOLUTION_PORTRAIT_HEIGHT=1024

export RESOLUTION_LANDSCAPE_WIDTH=1024
export RESOLUTION_LANDSCAPE_HEIGHT=768

export RESOLUTION_HD_WIDTH=1280
export RESOLUTION_HD_HEIGHT=720

export RESOLUTION_4K_WIDTH=3840
export RESOLUTION_4K_HEIGHT=2160

# Function: Build SSH command with standard options
# Usage: ssh_cmd <host> <port> <key> <command>
ssh_cmd() {
    local host="$1"
    local port="$2"
    local key="$3"
    local command="$4"

    ssh -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
        -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY}" \
        -p "${port}" \
        -i "${key}" \
        "${host}" \
        "${command}"
}

# Function: Build SCP command with standard options
# Usage: scp_cmd <key> <port> <source> <destination>
scp_cmd() {
    local key="$1"
    local port="$2"
    local source="$3"
    local destination="$4"

    scp -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
        -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY}" \
        -P "${port}" \
        -i "${key}" \
        "${source}" \
        "${destination}"
}

# Function: Test SSH connection
# Usage: test_ssh_connection <host> <port> <key>
# Returns: 0 if connection successful, 1 otherwise
test_ssh_connection() {
    local host="$1"
    local port="$2"
    local key="$3"

    if ssh_cmd "${host}" "${port}" "${key}" "echo 'OK'" 2>&1 | grep -q "OK"; then
        return 0
    else
        return 1
    fi
}

# Function: Parse resolution argument
# Usage: parse_resolution "WIDTHxHEIGHT"
# Sets: PARSED_WIDTH and PARSED_HEIGHT global variables
parse_resolution() {
    local resolution="$1"

    if [[ "$resolution" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        PARSED_WIDTH="${BASH_REMATCH[1]}"
        PARSED_HEIGHT="${BASH_REMATCH[2]}"
        return 0
    else
        echo "ERROR: Invalid resolution format. Use WIDTHxHEIGHT (e.g., 1024x768)" >&2
        return 1
    fi
}

# Display configuration (for debugging)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "FLUX Image Generator - Shell Configuration"
    echo "=========================================="
    echo ""
    echo "RunPod Paths:"
    echo "  WORKSPACE_PATH:    ${WORKSPACE_PATH}"
    echo "  WORKSPACE_CACHE:   ${WORKSPACE_CACHE}"
    echo "  WORKSPACE_VENV:    ${WORKSPACE_VENV}"
    echo "  WORKSPACE_SCRIPTS: ${WORKSPACE_SCRIPTS}"
    echo "  WORKSPACE_OUTPUTS: ${WORKSPACE_OUTPUTS}"
    echo "  HF_CACHE:          ${HF_CACHE}"
    echo ""
    echo "SSH Configuration:"
    echo "  SSH_CONNECT_TIMEOUT:    ${SSH_CONNECT_TIMEOUT}"
    echo "  SSH_STRICT_HOST_KEY:    ${SSH_STRICT_HOST_KEY}"
    echo ""
    echo "Quality Presets:"
    echo "  STEPS_FAST:      ${STEPS_FAST}"
    echo "  STEPS_BALANCED:  ${STEPS_BALANCED}"
    echo "  STEPS_QUALITY:   ${STEPS_QUALITY}"
    echo ""
    echo "Guidance Scale Presets:"
    echo "  GUIDANCE_CREATIVE: ${GUIDANCE_CREATIVE}"
    echo "  GUIDANCE_DEFAULT:  ${GUIDANCE_DEFAULT}"
    echo "  GUIDANCE_STRICT:   ${GUIDANCE_STRICT}"
    echo ""
    echo "Resolution Presets:"
    echo "  Square:    ${RESOLUTION_SQUARE_WIDTH}x${RESOLUTION_SQUARE_HEIGHT}"
    echo "  Portrait:  ${RESOLUTION_PORTRAIT_WIDTH}x${RESOLUTION_PORTRAIT_HEIGHT}"
    echo "  Landscape: ${RESOLUTION_LANDSCAPE_WIDTH}x${RESOLUTION_LANDSCAPE_HEIGHT}"
    echo "  HD:        ${RESOLUTION_HD_WIDTH}x${RESOLUTION_HD_HEIGHT}"
    echo "  4K:        ${RESOLUTION_4K_WIDTH}x${RESOLUTION_4K_HEIGHT}"
fi
