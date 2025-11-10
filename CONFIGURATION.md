# Configuration Guide

This document describes all configuration options for the FLUX Image Generator.

## Configuration Files

The system uses three configuration layers:

1. **`config.env`** - Secrets and connection details (NOT in git)
2. **`config_defaults.yaml`** - Default values for all settings
3. **`lib/config.sh`** - Shell script configuration and helper functions

### Priority Order

Configuration values are resolved in this order (highest to lowest priority):

1. **CLI flags** - Command line arguments (e.g., `--seed 12345`)
2. **Environment variables** - Shell environment (e.g., `STEPS_QUALITY=100`)
3. **Config files** - YAML/env files
4. **Dataclass defaults** - Hardcoded in `config.py`

Example:
```bash
# Default from config_defaults.yaml
bash flux-generate.sh "test" --quality
# Uses steps_quality: 50

# Override with environment variable
STEPS_QUALITY=100 bash flux-generate.sh "test" --quality
# Uses 100 steps

# Override with CLI flag (highest priority)
bash flux-generate.sh "test" 75
# Uses 75 steps (if positional arg supported)
```

---

## 1. Secrets Configuration (`config.env`)

**Location**: `~/flux-image-generator/config.env`
**Template**: `.env.example`
**Git**: ❌ NOT committed (in `.gitignore`)

### Required Values

```bash
# API Keys
ANTHROPIC_API_KEY=sk-ant-api03-...    # Get from https://console.anthropic.com/
HUGGINGFACE_TOKEN=hf_...              # Get from https://huggingface.co/settings/tokens

# RunPod Connection (changes with each pod deployment)
RUNPOD_HOST=123.45.67.89              # Pod IP address
RUNPOD_PORT=12345                     # SSH port
RUNPOD_USER=root                      # SSH user (default: root)
SSH_KEY=~/.ssh/id_ed25519             # SSH private key path

# Local Output Directories
WINDOWS_USERNAME=your_username
OUTPUT_DIR_WSL=/mnt/c/Users/${WINDOWS_USERNAME}/Pictures/FLUX
OUTPUT_DIR_WINDOWS=C:\\Users\\${WINDOWS_USERNAME}\\Pictures\\FLUX
```

### Setup

```bash
# Copy template
cp .env.example config.env

# Edit with your values
nano config.env

# Source in scripts
source config.env
```

---

## 2. Python Configuration (`config_defaults.yaml`)

**Location**: `~/flux-image-generator/config_defaults.yaml`
**Loaded by**: `config.py`
**Git**: ✅ Committed (safe to customize locally)

### Full Configuration

```yaml
# RunPod Path Configuration
paths:
  workspace: "/workspace"
  cache: "/workspace/.cache"
  venv: "/workspace/.venv"
  scripts: "/workspace/scripts"
  outputs: "/workspace/outputs"
  hf_cache: "/workspace/.cache/huggingface"

# Image Generation Parameters
generation:
  # Default resolution
  height: 1024
  width: 1024

  # Quality presets (inference steps)
  steps_fast: 4          # ~10-15 seconds
  steps_balanced: 20     # ~30-45 seconds
  steps_quality: 50      # ~1-2 minutes

  # Guidance scale presets
  guidance_creative: 1.5   # More artistic freedom
  guidance_default: 3.5    # Balanced (recommended)
  guidance_strict: 5.0     # Strict prompt adherence
  guidance_min: 1.0        # Validation minimum
  guidance_max: 7.0        # Validation maximum

  # Model configuration
  model_id: "black-forest-labs/FLUX.1-dev"
  torch_dtype: "bfloat16"  # Options: bfloat16, float16
  max_sequence_length: 512 # FLUX model limit

  # Output quality
  jpeg_quality: 95         # JPEG compression (1-100)

  # Seed behavior
  random_seed: true        # Use random seed by default
  fixed_seed: 42           # Seed when random_seed is false

# Claude API Configuration
claude:
  model: "claude-sonnet-4-5-20250929"
  max_tokens: 120
  temperature: 0.7
  timeout: 30              # Seconds

  system_prompt: "FLUX.1 enhancer. Under 50 words: subject, mood, camera (vary!), lighting, 8k. Return ONLY prompt."
  system_prompt_file: "prompts/claude_system.txt"  # Takes precedence if exists

# HuggingFace API Configuration (fallback enhancement)
huggingface:
  model: "google/flan-t5-base"
  timeout: 30
  max_length: 150
  temperature: 0.7
  wait_for_model: true

# CLIP Tokenizer Configuration
clip:
  model: "openai/clip-vit-large-patch14"
  max_tokens: 77           # FLUX hard limit
  word_to_token_ratio: 1.6 # Fallback estimation

# SSH Connection Configuration
ssh:
  connect_timeout: 10
  strict_host_key_checking: "accept-new"  # Options: no, accept-new, yes
  compression: true
```

### Access from Python

```python
from config import config

# Access values
height = config.generation.height              # 1024
model = config.claude.model                    # "claude-sonnet-4-5-20250929"
timeout = config.ssh.connect_timeout           # 10

# Use in code
image = pipe(
    prompt=prompt,
    height=config.generation.height,
    width=config.generation.width,
    guidance_scale=config.generation.guidance_default
)
```

### View Current Config

```bash
# Display all Python configuration
python3 config.py
```

---

## 3. Shell Configuration (`lib/config.sh`)

**Location**: `~/flux-image-generator/lib/config.sh`
**Sourced by**: All shell scripts
**Git**: ✅ Committed

### Variables

```bash
# RunPod Paths (can be overridden by environment)
WORKSPACE_PATH=/workspace
WORKSPACE_CACHE=/workspace/.cache
WORKSPACE_VENV=/workspace/.venv
WORKSPACE_SCRIPTS=/workspace/scripts
WORKSPACE_OUTPUTS=/workspace/outputs
HF_CACHE=/workspace/.cache/huggingface

# SSH Configuration
SSH_CONNECT_TIMEOUT=10
SSH_STRICT_HOST_KEY=accept-new

# Quality Presets (inference steps)
STEPS_FAST=4
STEPS_BALANCED=20
STEPS_QUALITY=50

# Guidance Scale Presets
GUIDANCE_CREATIVE=1.5
GUIDANCE_DEFAULT=3.5
GUIDANCE_STRICT=5.0

# Image Generation Defaults
DEFAULT_HEIGHT=1024
DEFAULT_WIDTH=1024
DEFAULT_JPEG_QUALITY=95

# Resolution Presets
RESOLUTION_SQUARE_WIDTH=1024
RESOLUTION_SQUARE_HEIGHT=1024

RESOLUTION_PORTRAIT_WIDTH=768
RESOLUTION_PORTRAIT_HEIGHT=1024

RESOLUTION_LANDSCAPE_WIDTH=1024
RESOLUTION_LANDSCAPE_HEIGHT=768

RESOLUTION_HD_WIDTH=1280
RESOLUTION_HD_HEIGHT=720

RESOLUTION_4K_WIDTH=3840
RESOLUTION_4K_HEIGHT=2160
```

### Helper Functions

```bash
# SSH command with standard options
ssh_cmd <host> <port> <key> <command>

# SCP command with standard options
scp_cmd <key> <port> <source> <destination>

# Test SSH connection
test_ssh_connection <host> <port> <key>

# Parse resolution string
parse_resolution "WIDTHxHEIGHT"
# Sets PARSED_WIDTH and PARSED_HEIGHT
```

### Usage in Scripts

```bash
#!/bin/bash
# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

# Use variables
ssh_cmd "${RUNPOD_USER}@${RUNPOD_HOST}" "${RUNPOD_PORT}" "${SSH_KEY}" \
    "cd ${WORKSPACE_PATH} && ls -la"

# Use helper functions
if test_ssh_connection "${RUNPOD_HOST}" "${RUNPOD_PORT}" "${SSH_KEY}"; then
    echo "Connection OK"
fi

# Use presets
STEPS=${STEPS_QUALITY}  # 50
GUIDANCE=${GUIDANCE_CREATIVE}  # 1.5
```

### View Current Config

```bash
# Display all shell configuration
bash lib/config.sh
```

---

## 4. Logging Configuration

Logging is controlled in Python scripts via `logger.py`.

### Default Behavior

- **Console**: INFO level, colored output
- **File**: DEBUG level, timestamped, in `logs/` directory

### Log Files

```
logs/
├── flux-generator.log      # Main script logging
├── enhance-claude.log      # Claude API enhancement
└── enhance-hf.log          # HuggingFace enhancement
```

### Customization

```python
from logger import setup_logger

# Create custom logger
logger = setup_logger(
    'my_script',
    log_file='logs/my_script.log',
    level=logging.DEBUG,       # Set default level
    console_level=logging.INFO, # Override console level
    file_level=logging.DEBUG,   # Override file level
    use_colors=True            # Enable colored console output
)

logger.debug("Detailed debug info")
logger.info("General information")
logger.warning("Warning message")
logger.error("Error occurred")
```

---

## Configuration Examples

### Example 1: Custom Quality Presets

**Scenario**: You want faster previews and longer high-quality renders

**Edit `config_defaults.yaml`**:
```yaml
generation:
  steps_fast: 2        # Ultra-fast preview (was 4)
  steps_balanced: 15   # Faster balanced (was 20)
  steps_quality: 100   # Very high quality (was 50)
```

**Or use environment variables**:
```bash
export STEPS_FAST=2
export STEPS_BALANCED=15
export STEPS_QUALITY=100
bash flux-generate.sh "test" --quality  # Uses 100 steps
```

### Example 2: Different Default Resolution

**Scenario**: You primarily generate portrait images

**Edit `config_defaults.yaml`**:
```yaml
generation:
  height: 1024
  width: 768   # Portrait by default (was 1024)
```

**Or use CLI flags**:
```bash
bash flux-generate.sh "portrait" --portrait  # Forces 768x1024
```

### Example 3: Custom RunPod Paths

**Scenario**: Your RunPod setup uses different paths

**Set environment variables before running scripts**:
```bash
export WORKSPACE_PATH=/custom/path
export WORKSPACE_CACHE=/custom/path/cache
bash flux-generate.sh "test"
```

**Or edit `lib/config.sh`** directly:
```bash
export WORKSPACE_PATH="${WORKSPACE_PATH:-/custom/path}"
```

### Example 4: Disable Random Seeds

**Scenario**: You want reproducible results by default

**Edit `config_defaults.yaml`**:
```yaml
generation:
  random_seed: false   # Use fixed seed (was true)
  fixed_seed: 12345    # Your preferred seed (was 42)
```

Now all generations use seed 12345 unless you specify `--seed` or `--random-seed`.

### Example 5: Higher JPEG Quality

**Scenario**: You need maximum quality for prints

**Edit `config_defaults.yaml`**:
```yaml
generation:
  jpeg_quality: 100    # Maximum quality (was 95)
```

**Or use CLI flag**:
```bash
bash flux-generate.sh "test" --jpeg-quality 100
```

### Example 6: Custom SSH Timeout

**Scenario**: Your network connection is slow

**Edit `lib/config.sh`**:
```bash
export SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-30}"  # Was 10
```

**Or set environment variable**:
```bash
export SSH_CONNECT_TIMEOUT=30
bash flux-generate.sh "test"
```

---

## Validation Rules

The configuration system includes validation:

### Python (config.py)

```python
# Guidance scale range
if not config.generation.guidance_min <= guidance_scale <= config.generation.guidance_max:
    raise ValueError("guidance_scale out of range")

# JPEG quality range
if not 1 <= jpeg_quality <= 100:
    raise ValueError("jpeg_quality must be 1-100")

# Positive dimensions
if height <= 0 or width <= 0:
    raise ValueError("height and width must be positive")

# SSH strict host key checking
if strict_host_key_checking not in ["no", "accept-new", "yes"]:
    raise ValueError("Invalid SSH option")
```

### Shell (lib/config.sh)

```bash
# Resolution parsing
if [[ ! "$resolution" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    echo "ERROR: Invalid resolution format" >&2
    return 1
fi
```

---

## Troubleshooting

### Config file not found

```
ERROR: Could not import config/logger
```

**Solution**: The config system has fallbacks. If you see this, config.py is using minimal hardcoded defaults.

```python
# Check if config loaded
python3 config.py  # Shows current configuration
```

### SSH connection fails

```
ERROR: Could not connect to RunPod
```

**Check**:
1. `config.env` has correct RUNPOD_HOST and RUNPOD_PORT
2. SSH_KEY path is correct
3. RunPod pod is running

```bash
# Test connection manually
ssh -p ${RUNPOD_PORT} root@${RUNPOD_HOST} -i ${SSH_KEY} "echo OK"
```

### API key not found

```
ERROR: ANTHROPIC_API_KEY environment variable not set
```

**Solution**: Source config.env before running scripts

```bash
source config.env
python3 enhance-prompt-claude.py "test"
```

### Validation errors

```
ERROR: guidance_scale 10.0 out of range [1.0-7.0]
```

**Solution**: Adjust your value or change validation limits in `config_defaults.yaml`

```yaml
generation:
  guidance_max: 15.0  # Allow higher values
```

---

## Configuration Best Practices

1. **Never commit `config.env`** - Contains secrets
2. **Customize `config_defaults.yaml` locally** - Safe to modify
3. **Use environment variables for temporary overrides** - Don't edit files for one-off changes
4. **Use CLI flags for per-generation settings** - Resolution, seed, quality
5. **Document custom configurations** - Add comments to your YAML
6. **Back up your config.env** - Before major changes
7. **Use `.env.example` as template** - Keep it updated

---

## See Also

- [README.md](README.md) - Quick start guide
- [CLAUDE.md](CLAUDE.md) - Architecture and technical details
- [CHANGELOG.md](CHANGELOG.md) - Version history and breaking changes
