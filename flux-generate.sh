#!/bin/bash

CONFIG_FILE=~/flux-image-generator/config.env
source "$CONFIG_FILE"

if [ -n "$ANTHROPIC_API_KEY" ]; then
    export ANTHROPIC_API_KEY
fi

if [ -n "$HUGGINGFACE_TOKEN" ]; then
    export HUGGINGFACE_TOKEN
fi

STEPS=4
QUALITY_MODE="fast"
ENHANCE_AI=false
PROMPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --fast) STEPS=4; QUALITY_MODE="fast"; shift ;;
        --balanced) STEPS=20; QUALITY_MODE="balanced"; shift ;;
        --quality) STEPS=50; QUALITY_MODE="quality"; shift ;;
        --enhance-ai) ENHANCE_AI=true; shift ;;
        *) PROMPT="$1"; shift ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="flux_${TIMESTAMP}.jpg"

if [ "$ENHANCE_AI" = true ]; then
    printf "=== Enhancing Prompt with Claude API ===\n"
    printf "Original: %s\n" "$PROMPT"
    ENHANCED_PROMPT=$(python3 ~/flux-image-generator/src/enhance-prompt-claude.py "$PROMPT")
    if [ -n "$ENHANCED_PROMPT" ]; then
        PROMPT="$ENHANCED_PROMPT"
        printf "Enhanced: %s\n" "$PROMPT"
    fi
    printf "\n"
fi

printf "=== Generating Image ===\n"
printf "Prompt: %s\n" "$PROMPT"
printf "Quality: %s (%d steps)\n" "$QUALITY_MODE" "$STEPS"
printf "File: %s\n" "$FILENAME"
printf "Prompt length: %d characters\n" "${#PROMPT}"
printf "\n"

printf "Connecting to RunPod...\n"
ESCAPED_PROMPT=$(printf %q "$PROMPT")

ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  "export HUGGINGFACE_TOKEN='${HUGGINGFACE_TOKEN}' && export HF_HOME='/workspace/.cache' && cd /workspace && source .venv/bin/activate && python3 scripts/generate.py ${ESCAPED_PROMPT} '$FILENAME' $STEPS" 2>&1

SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    printf "\nERROR: Generation failed with exit code %d\n" "$SSH_EXIT" >&2
    exit $SSH_EXIT
fi

printf "\n=== Downloading Image ===\n"

mkdir -p "$OUTPUT_DIR_WSL"

scp -i "$SSH_KEY" -P ${RUNPOD_PORT} -o StrictHostKeyChecking=no \
  root@${RUNPOD_HOST}:/workspace/outputs/${FILENAME} \
  "$OUTPUT_DIR_WSL/"

SCP_EXIT=$?
if [ $SCP_EXIT -ne 0 ]; then
    printf "\nERROR: Download failed with exit code %d\n" "$SCP_EXIT" >&2
    exit $SCP_EXIT
fi

printf "\n"
printf "✓ Image saved: %s\\%s\n" "$OUTPUT_DIR_WINDOWS" "$FILENAME"
printf "Opening image...\n"

WINDOWS_PATH="${OUTPUT_DIR_WINDOWS}\\${FILENAME}"
powershell.exe -Command "Start-Process -FilePath '$WINDOWS_PATH'"

printf "✓ Complete!\n"
