# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Image Generation
- **Main generation script**: `bash flux-generate.sh "prompt" [flags]`
  - Quality presets: `--fast` (4 steps), `--balanced` (20 steps), `--quality` (50 steps)
  - Resolution presets: `--square`, `--portrait`, `--landscape`, `--hd`, `--4k`, `--custom WxH`
  - Seed control: `--seed N` (reproducible), `--random-seed` (default)
  - Guidance scale: `--creative` (1.5), `--guidance X` (1.0-7.0), `--strict` (5.0)
  - JPEG quality: `--jpeg-quality N` (1-100, default 95)
  - Prompt enhancement: `--enhance-ai` (uses Claude API)
  - Help: `--help` for full documentation
  - Examples:
    - `bash flux-generate.sh "sunset over mountains" --quality --enhance-ai --creative`
    - `bash flux-generate.sh "portrait" --portrait --seed 12345 --balanced`
    - `bash flux-generate.sh "logo" --custom 512x512 --fast`

### RunPod Deployment
- **Upload generation script**: `bash upload-script.sh`
- **Initial setup**: `bash scripts/deploy.sh` (creates venv, installs dependencies, downloads FLUX model)
- **Test generation**: `bash scripts/generate.sh "test prompt"`

### Testing
- **CLIP token validation**: `python3 test-clip.py "prompt text"`
- **Prompt enhancement test**: `python3 test-enhance-verbose.py "prompt"`
- **HuggingFace model test**: `python3 test-hf-models.py`

### Configuration
- **Secrets**: `config.env` (API keys, RunPod connection) - NOT in git
  - Template: `.env.example`
  - Contains: ANTHROPIC_API_KEY, HUGGINGFACE_TOKEN, RUNPOD_HOST, RUNPOD_PORT, SSH_KEY, OUTPUT_DIR_WSL, OUTPUT_DIR_WINDOWS
- **Python config**: `config_defaults.yaml` (quality presets, resolution defaults, timeouts)
  - Loaded by `config.py` dataclass system
  - Override via environment variables or CLI flags
- **Shell config**: `lib/config.sh` (RunPod paths, SSH settings, quality presets)
  - Sourced by all shell scripts
  - Provides helper functions: `ssh_cmd()`, `scp_cmd()`, `parse_resolution()`
- **Logging**: `logger.py` (centralized logging for Python scripts)
  - Console output: INFO level with colors
  - File output: DEBUG level in `logs/` directory
- **View current config**: `python3 config.py` or `bash lib/config.sh`

## Architecture

### Execution Flow
1. **Local (WSL)**: `flux-generate.sh` reads config.env and parses CLI flags
2. **Prompt Enhancement** (optional): `enhance-prompt-claude.py` calls Claude Sonnet 4.5 API to expand short prompts
3. **CLIP Validation**: Enhanced prompts are trimmed to 77 CLIP tokens (FLUX model limit)
4. **Remote Execution**: SSH to RunPod pod, execute `generate.py` with venv activated
5. **Image Generation**: FLUX.1-dev model runs with CPU offloading (24GB VRAM optimization)
6. **Download**: SCP transfers image from RunPod to local WSL and Windows directories
7. **Display**: PowerShell auto-opens image in Windows default viewer

### Key Components

**Generation Pipeline** (`generate.py`):
- Loads FLUX.1-dev model from HuggingFace (config.generation.model_id)
- Uses argparse for CLI argument parsing
- Configurable parameters:
  - Resolution: `--height`, `--width` (default from config)
  - Seed: `--seed N` or random (config.generation.random_seed)
  - JPEG quality: `--quality` (default 95)
  - CPU offloading: `--cpu-offload` (default enabled) / `--no-cpu-offload`
- Uses `torch.bfloat16` for dtype (config.generation.torch_dtype)
- Enables CPU offloading by default via `pipe.enable_model_cpu_offload()`
- Fixed parameters: max_sequence_length=512
- Falls back to minimal config if config.py unavailable

**Prompt Enhancement** (`enhance-prompt-claude.py`):
- Uses centralized logging system (logs to console + `logs/enhance-claude.log`)
- Calls Claude Sonnet 4.5 with config values (temperature=0.7, max_tokens=120)
- System prompt loaded from `prompts/claude_system.txt` or config
- CLIP tokenizer validation:
  - Logs warning if tokenizer unavailable, uses word-count estimation
  - Specific exception handling (ImportError vs Exception)
  - Trims to exactly 77 tokens
- Error handling:
  - No silent fallbacks - exits with error code 1 on failure
  - Logs HTTP error details, network errors, parse errors
  - Suppresses only specific transformers warnings
- Uses config.claude.* and config.clip.* values

**SSH Orchestration** (`flux-generate.sh`):
- Sources `lib/config.sh` for paths and presets, then `config.env` for secrets
- Parses extensive CLI flags (resolution, seed, quality, guidance, enhancement)
- Exports HUGGINGFACE_TOKEN and HF_HOME environment variables to RunPod
- Activates `/workspace/.venv` Python virtual environment before execution
- SSH security: `StrictHostKeyChecking=accept-new` (prevents MITM, allows dynamic IPs)
- Connection timeout: 10 seconds (configurable in lib/config.sh)
- Builds generate.py command with all parameters (height, width, seed, quality)
- Uses variables from lib/config.sh:
  - `${WORKSPACE_PATH}`, `${WORKSPACE_CACHE}`, `${WORKSPACE_SCRIPTS}`, `${WORKSPACE_OUTPUTS}`
  - `${STEPS_FAST}`, `${STEPS_BALANCED}`, `${STEPS_QUALITY}`
  - `${GUIDANCE_CREATIVE}`, `${GUIDANCE_DEFAULT}`, `${GUIDANCE_STRICT}`
- Resolution presets: square, portrait, landscape, HD, 4K, custom
- Enhanced output display: shows resolution, seed, quality, all parameters

### Remote Environment (RunPod)
- **Base Image**: runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04
- **GPU**: RTX 4090 (24GB VRAM minimum)
- **Storage**:
  - Container disk: 10GB (ephemeral, resets on pod termination)
  - Network volume: 50GB (persistent, mounted at /workspace)
  - Model cache: /workspace/.cache (~32GB for FLUX.1-dev)
- **Python Environment**: /workspace/.venv (managed by deploy.sh)
- **Scripts**: /workspace/scripts/generate.py
- **Outputs**: /workspace/outputs/flux_YYYYMMDD_HHMMSS.jpg

### Configuration Dependencies
- **FLUX.1-dev model**: Requires HuggingFace token (gated model)
- **Prompt enhancement**: Requires Anthropic API key
- **RunPod connection**: Requires SSH key (~/.ssh/id_ed25519), dynamic IP/port (changes on each pod deployment)
- **CLIP validation**: Uses openai/clip-vit-large-patch14 tokenizer (77 token hard limit)

## Important Technical Details

### VRAM Optimization
FLUX.1-dev requires >24GB VRAM in standard mode. The codebase uses:
- `torch.bfloat16` (NOT float16) for model dtype
- `pipe.enable_model_cpu_offload()` to dynamically move model components between GPU/CPU
- Never use `.to('cuda')` directly - CPU offloading handles device placement
- Lower step counts (4-20) reduce memory pressure vs 50 steps

### CLIP Token Limit
FLUX models use CLIP text encoder with 77 token hard limit:
- Prompts exceeding 77 tokens will be truncated by the model
- `enhance-prompt-claude.py` validates and trims to 77 tokens before generation
- Token count ≠ word count (punctuation, special characters affect tokenization)
- Use `test-clip.py` to validate prompt token counts

### RunPod Persistence Model
- **Pod IP/port changes** on every deployment - must update config.env
- **Network volume persists** across pod terminations (model cache, venv)
- **Container state is ephemeral** - all critical data must be in /workspace
- **First deployment**: 10-15 min (downloads 24GB model to volume)
- **Subsequent deployments**: 30 sec (model already cached)

### Guidance Scale Behavior
- **1.0-2.0**: Maximum artistic freedom, may diverge from prompt
- **2.0-4.0**: Balanced (default: 3.5)
- **4.0-7.0**: Strict adherence to prompt, may reduce image quality
- FLUX.1-dev performs best at 1.5-3.5 range

## File Structure

```
/home/rbsmith4/flux-image-generator/
├── flux-generate.sh              # Main CLI entry point (local)
├── generate.py                   # FLUX model execution (runs on RunPod)
├── enhance-prompt-claude.py      # Claude API prompt enhancement
├── enhance-prompt.py             # Fallback enhancement (no Claude)
├── upload-script.sh              # Deploy generate.py to RunPod
├── config.env                    # Credentials and connection config
├── scripts/
│   ├── deploy.sh                 # Initial RunPod setup (venv, deps, model download)
│   ├── generate.sh               # Alternative generation wrapper
│   ├── download.sh               # Download images from RunPod
│   └── setup_runpod.sh           # RunPod environment configuration
├── outputs/                      # Local image storage (WSL)
└── test-*.py                     # Validation and debugging scripts
```

## Common Workflows

### First-Time RunPod Setup
1. Deploy RunPod pod from "FLUX Generator" template (see WORKFLOW.md)
2. Update config.env with new RUNPOD_HOST and RUNPOD_PORT
3. Restore HuggingFace token to pod: `ssh root@<IP> -p <PORT> -i ~/.ssh/id_ed25519 "mkdir -p ~/.cache/huggingface && echo '<TOKEN>' > ~/.cache/huggingface/token"`
4. Run `bash scripts/deploy.sh` (10-15 min for model download)
5. Test: `bash flux-generate.sh "test prompt" --fast`

### Subsequent Pod Deployments
1. Deploy pod with same template + existing volume ("flux-storage")
2. Update config.env with new IP/port
3. Generate images immediately (model already cached)
4. Terminate pod when done to stop compute costs

### Modifying Generation Code
1. Edit generate.py locally
2. Run `bash upload-script.sh` to deploy to RunPod
3. Test with `bash flux-generate.sh "test" --fast`

### Debugging Prompt Enhancement
1. Test locally: `python3 enhance-prompt-claude.py "your prompt"`
2. Verify token count: `python3 test-clip.py "enhanced prompt output"`
3. Use `test-enhance-verbose.py` for detailed debugging output
