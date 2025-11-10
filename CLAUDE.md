# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Commands
```bash
# Main generation workflow
bash flux-generate.sh "prompt" [--quality|--balanced|--fast] [--enhance-ai] [--portrait|--landscape|--4k]

# Update RunPod connection after pod restart (auto-fetches new IP/port)
bash scripts/update-pod-connection.sh

# Upload modified scripts to RunPod
bash scripts/upload-script.sh

# Direct RunPod SSH access
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY}

# View current configuration
python3 config/config.py

# Test prompt enhancement directly
python3 src/enhance-prompt-claude.py "test prompt"
```

### RunPod Direct Commands
```bash
# Check disk usage on network volume
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY} "df -h /workspace"

# Manually run generation on RunPod
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY} \
  "cd /workspace && source .venv/bin/activate && python3 scripts/generate.py 'prompt' 'output.jpg' 20"
```

## Architecture

### Hybrid Execution Model (WSL + RunPod)

This project uses a **split execution architecture**:

**WSL Side (Local Machine)**:
- Entry point: `flux-generate.sh`
- Configuration: `config.env` (secrets), `config_defaults.yaml` (parameters)
- Prompt enhancement: `src/enhance-prompt-claude.py` → Claude API
- CLIP tokenization: Trims prompts to 77 tokens
- File management: Downloads images, auto-opens in Windows Photos

**RunPod Side (GPU Server)**:
- Image generation: `src/generate.py` (executed via SSH)
- FLUX.1-dev model loading and inference
- Persistent storage: `/workspace/` (50GB network volume)
- Model cache: `/workspace/.cache/` (32GB, persists across restarts)
- Python environment: `/workspace/.venv/` (7.9GB, persists)

**Data Flow**:
```
User → flux-generate.sh → enhance-prompt-claude.py (Claude API) → trim_to_77()
  → SSH to RunPod → generate.py (FLUX inference) → /workspace/outputs/
  → SCP download → WSL → Windows Pictures → Auto-open
```

### Configuration System (Three-Layer Priority)

Configuration is resolved in this priority order (highest to lowest):

1. **CLI flags** → `--quality`, `--seed 12345`, `--portrait`
2. **Environment variables** → `STEPS_QUALITY=100`
3. **Config files**:
   - `config.env` - Secrets (API keys, RunPod connection) **NOT in git**
   - `config_defaults.yaml` - Tunable parameters (steps, guidance, model config)
   - `config/lib/config.sh` - Shell script helpers
4. **Dataclass defaults** - Hardcoded fallbacks in `config/config.py`

**Key Design**: Separation of secrets (`config.env`) from parameters (`config_defaults.yaml`) enables safe git commits.

### CLIP Token Trimming (Critical for FLUX)

FLUX.1-dev has a **hard 77-token limit** via CLIP tokenizer:

1. `enhance-prompt-claude.py` → Claude API (targets <50 words)
2. `count_clip_tokens()` → Uses `transformers.CLIPTokenizer` for actual token count
3. If >77 tokens: `trim_to_77()` → Decodes first 77 tokens, preserving meaning
4. Fallback: 1.6 word-to-token ratio if tokenizer unavailable

**Why this matters**: Without trimming, FLUX silently truncates at 77 tokens mid-word, corrupting prompts.

### RunPod Persistence Model

**Critical distinction**:
- **Container disk**: 10GB, ephemeral, resets on restart
- **Network volume** (`/workspace/`): 50GB, persistent ($5/month)

**What persists**:
- FLUX.1-dev model cache: 32GB in `/workspace/.cache/`
- Python venv: 7.9GB in `/workspace/.venv/`
- Generation scripts: `/workspace/scripts/`

**What changes on restart**:
- RunPod assigns new IP/SSH port → Run `scripts/update-pod-connection.sh` to auto-update `config.env`

## Code Structure Patterns

### Python Scripts (`src/`)

All Python scripts follow this pattern:
```python
#!/usr/bin/env python3
import sys
from config import config  # Centralized config singleton

def main():
    try:
        # Validate inputs
        if len(sys.argv) < required:
            print("ERROR: ...", file=sys.stderr)
            sys.exit(1)

        # Use config.* for all parameters
        height = config.generation.height

        # CRITICAL: Always flush for SSH streaming
        print("Status update...", flush=True)

    except Exception as e:
        # Always stderr for SSH error capture
        print(f"FATAL ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
```

**Key patterns**:
- Use `flush=True` for real-time output over SSH
- Print errors to `stderr` with prefixes (`ERROR:`, `FATAL ERROR:`)
- Import config singleton: `from config import config`
- Always catch exceptions and print traceback for remote debugging

### Shell Scripts

All shell scripts source configuration:
```bash
#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"
source "$CONFIG_FILE"

# Use printf for consistent formatting
printf "=== Section ===\n"
printf "Status: %s\n" "$VARIABLE"

# Always quote variables for spaces
ssh root@"${RUNPOD_HOST}" -p "${RUNPOD_PORT}" -i "$SSH_KEY" "command"

# Check exit codes explicitly
SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    printf "\nERROR: Failed\n" >&2
    exit $SSH_EXIT
fi
```

**Key patterns**:
- Use `set -e` to fail fast
- Use `printf` instead of `echo` for formatting
- Always quote: `"${VAR}"` not `$VAR`
- Source `config.env` for secrets

### Configuration Access

**From Python**:
```python
from config import config

# Access nested config
height = config.generation.height
model = config.claude.model
cache_path = config.paths.hf_cache

# Config is immutable after load
```

**From Shell**:
```bash
source "config/lib/config.sh"

# Use predefined variables
ssh_cmd "${RUNPOD_HOST}" "${RUNPOD_PORT}" "${SSH_KEY}" "ls ${WORKSPACE_PATH}"

# Use presets
STEPS=${STEPS_QUALITY}  # 50
```

## Critical Constraints

### VRAM Management
- FLUX.1-dev requires >24GB VRAM in bfloat16
- `generate.py` uses `pipe.enable_model_cpu_offload()` to manage memory
- **Never disable CPU offload** - will OOM on RTX 4090 (24GB)
- Higher steps (50+) push VRAM limits - reduce if OOM

### Disk Space Management
- Container disk: Only 10GB - don't write large files
- Network volume: 50GB - use `/workspace/` for all persistent data
- Always set `HF_HOME=/workspace/.cache` before HuggingFace ops
- Check: `du -sh /workspace/.cache`

## Development Workflows

### Adding New Quality Presets

1. Edit `config_defaults.yaml`:
```yaml
generation:
  steps_ultra: 100
```

2. Edit `config.py` dataclass:
```python
@dataclass
class GenerationConfig:
    steps_ultra: int = 100
```

3. Edit `flux-generate.sh` CLI parser:
```bash
case $1 in
    --ultra) STEPS=${STEPS_ULTRA}; shift ;;
```

### Modifying Prompt Enhancement

System prompt location: `prompts/claude_system.txt` (auto-loaded by `config.py`)

To change:
1. Edit `prompts/claude_system.txt`
2. Auto-reloads on next run
3. No code changes needed

Test: `python3 src/enhance-prompt-claude.py "test prompt"`

### Debugging RunPod Issues

```bash
# Test connection
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY} "echo OK"

# View disk space
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY} "df -h /workspace"

# Check model cache
ssh root@${RUNPOD_HOST} -p ${RUNPOD_PORT} -i ${SSH_KEY} "ls -lh /workspace/.cache/"
```

**Common failures**:
1. **New IP/port**: Run `bash scripts/update-pod-connection.sh`
2. **Model not cached**: First gen downloads 23GB (one-time)
3. **CUDA OOM**: Reduce steps or switch to FLUX.1-schnell
4. **SSH timeout**: Increase `SSH_CONNECT_TIMEOUT` in `config_defaults.yaml`

## Important Notes

### Windows Path Handling (WSL)
- WSL: `/mnt/c/Users/.../Pictures/FLUX`
- Windows: `C:\Users\...\Pictures\FLUX`
- Use double backslashes: `C:\\Users\\...`
- Use `powershell.exe` to open files from WSL

### Security
- `config.env` contains API keys - **NEVER commit**
- `.gitignore` excludes `config.env`, `*.env`, `*.backup`
- `.env.example` provides template without secrets
- SSH keys: `chmod 600 ~/.ssh/id_ed25519`

### Cost Optimization
- RunPod: ~$0.50/hour (RTX 4090) + $5/month (50GB storage)
- Stop pod when idle (storage persists)
- Use `--fast` (4 steps) for quick iterations
