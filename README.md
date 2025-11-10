# FLUX Image Generator

Automated FLUX.1-dev image generation using RunPod GPU instances with Claude API prompt enhancement.

## Features

- **AI-Enhanced Prompts**: Claude API automatically expands short prompts into detailed, high-quality descriptions
- **Resolution Presets**: Square, Portrait, Landscape, HD, 4K, or custom dimensions
- **Seed Control**: Random seeds by default, or specify for reproducible results
- **Guidance Scale Control**: Adjust creativity vs prompt adherence (1.0-7.0)
- **Quality Presets**: Fast (4 steps), Balanced (20 steps), Quality (50 steps)
- **JPEG Quality Control**: Configurable output quality (1-100)
- **Centralized Configuration**: YAML-based config with environment variable support
- **Comprehensive Logging**: Detailed logs for debugging and monitoring
- **Automated Workflow**: Generate → Download → Auto-open in Windows
- **Persistent Storage**: 50GB network volume caches model permanently

## Quick Usage

```bash
cd ~/flux-image-generator

# Generate with AI-enhanced prompt and creative guidance
bash flux-generate.sh "sunset over mountains" --quality --enhance-ai --creative

# Portrait photo with specific seed (reproducible)
bash flux-generate.sh "portrait photo" --balanced --portrait --seed 12345

# 4K landscape with custom quality
bash flux-generate.sh "mountain vista" --4k --quality --jpeg-quality 100

# Custom resolution
bash flux-generate.sh "logo design" --custom 512x512 --fast

# Get help
bash flux-generate.sh --help
```

## Command Line Flags

### Quality Presets
- `--fast` - 4 steps (~10-15 seconds)
- `--balanced` - 20 steps (~30-45 seconds)
- `--quality` - 50 steps (~1-2 minutes) **[RECOMMENDED]**

### Resolution Presets
- `--square` - 1024x1024 (default)
- `--portrait` - 768x1024 (3:4 aspect ratio)
- `--landscape` - 1024x768 (4:3 aspect ratio)
- `--hd` - 1280x720 (16:9 HD)
- `--4k` - 3840x2160 (16:9 4K)
- `--custom WxH` - Custom resolution (e.g., `--custom 1920x1080`)

### Seed Control
- `--seed N` - Use specific seed for reproducibility
- `--random-seed` - Use random seed (default)

### Guidance Scale
- `--creative` - guidance=1.5 (more artistic freedom)
- `--guidance X` - Custom value 1.0-7.0 (default: 3.5)
- `--strict` - guidance=5.0 (strict prompt adherence)

### Other Options
- `--enhance-ai` - Use Claude API to enhance prompt
- `--jpeg-quality N` - JPEG quality 1-100 (default: 95)
- `--help` - Show detailed help message

## Setup

### 1. Install Dependencies (WSL Ubuntu)
```bash
sudo apt update
sudo apt install python3 python3-pip
pip3 install -r requirements.txt
```

### 2. Configure Secrets

Copy the example configuration and fill in your values:
```bash
cp .env.example config.env
nano config.env
```

Required values in `config.env`:
```bash
# API Keys
ANTHROPIC_API_KEY=your_anthropic_key_here
HUGGINGFACE_TOKEN=your_hf_token_here

# RunPod Connection (update after each deployment)
RUNPOD_HOST=your.runpod.ip
RUNPOD_PORT=12345
SSH_KEY=~/.ssh/id_ed25519

# Local Output Directories
WINDOWS_USERNAME=your_username
OUTPUT_DIR_WSL=/mnt/c/Users/${WINDOWS_USERNAME}/Pictures/FLUX
OUTPUT_DIR_WINDOWS=C:\Users\${WINDOWS_USERNAME}\Pictures\FLUX
```

**Note**: All other configuration (quality presets, resolution defaults, etc.) is in `config_defaults.yaml`. See [CONFIGURATION.md](CONFIGURATION.md) for details.

### 3. Setup RunPod (First Time)

1. **Deploy Pod**:
   - Template: RunPod Pytorch 2.4.0
   - GPU: RTX 4090 (24GB VRAM)
   - Network Volume: 50GB ($5/month)
   - Mount path: `/workspace`

2. **Upload Script**:
```bash
bash upload-script.sh
```

3. **Set Cache Location** (SSH to pod):
```bash
echo 'export HF_HOME=/workspace/.cache' >> ~/.bashrc
source ~/.bashrc
```

Model will download once (~23GB) on first generation.

## Restarting After Shutdown

1. **Update config.env** with new pod IP/port:
```bash
nano ~/flux-image-generator/config.env
# Update RUNPOD_HOST and RUNPOD_PORT
```

2. **Test connection**:
```bash
ssh root@<NEW_IP> -p <NEW_PORT> -i ~/.ssh/id_ed25519
```

3. **Everything else persists** on network volume:
   - Model cache (32GB)
   - Python environment (7.9GB)
   - Scripts

## Known Issues

### CUDA Out of Memory
**Error**: `OutOfMemoryError: CUDA out of memory`

**Cause**: FLUX.1-dev needs >24GB VRAM in bfloat16

**Solutions**:
1. Use CPU offloading (already enabled in generate.py)
2. Reduce to 4-20 steps instead of 50
3. Switch to FLUX.1-schnell (faster, lower quality)

### Disk Space
- Container disk: 10GB (temporary, resets on restart)
- Network volume: 50GB (persistent)
- Model must be in `/workspace/.cache` (network volume)
- Check: `du -sh /workspace/.cache`

## Project Structure

```
~/flux-image-generator/
├── flux-generate.sh              # Main generation script
├── requirements.txt              # Python dependencies
├── config.env                    # Secrets (API keys, tokens) - NOT IN GIT
├── .env.example                  # Template for config.env
├── .gitignore                    # Git exclusions
│
├── config/                       # Configuration
│   ├── config.py                 # Python configuration system
│   ├── config_defaults.yaml      # Default configuration values
│   └── lib/
│       └── config.sh             # Shared shell configuration
│
├── src/                          # Source code
│   ├── generate.py               # RunPod generation script
│   ├── enhance-prompt-claude.py  # Claude API prompt enhancement
│   └── logger.py                 # Centralized logging
│
├── scripts/                      # Deployment scripts
│   ├── upload-script.sh          # Upload to RunPod
│   ├── setup_runpod.sh           # RunPod setup
│   ├── deploy.sh                 # Deployment helper
│   ├── download.sh               # Download helper
│   └── generate.sh               # Generation wrapper
│
├── prompts/                      # Prompt templates
│   └── claude_system.txt         # Claude system prompt
│
├── docs/                         # Additional documentation
│   ├── QUICKSTART.md             # Detailed setup guide
│   ├── WORKFLOW.md               # Usage workflows
│   ├── TROUBLESHOOTING.md        # Common issues
│   └── archive/                  # Archived development docs
│
├── outputs/                      # Generated images
└── logs/                         # Log files
```

## Configuration

See [CONFIGURATION.md](CONFIGURATION.md) for detailed configuration options.

**Quick reference**:
- Secrets: `config.env` (API keys, RunPod connection)
- Settings: `config_defaults.yaml` (quality presets, defaults)
- Paths: `lib/config.sh` (RunPod paths, SSH settings)

## Costs

- **Compute**: ~$0.50/hour (RTX 4090 on-demand)
- **Storage**: $5/month (50GB network volume)
- **Typical session**: 1-2 hours = ~$1

## Output

Images saved to:
- WSL: `~/flux-image-generator/outputs/`
- Windows: `C:\Users\rbsmi\Pictures\FLUX\`
- Filename: `flux_YYYYMMDD_HHMMSS.jpg`
