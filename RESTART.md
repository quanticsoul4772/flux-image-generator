# Restart Instructions - November 9, 2025

## What's Preserved on Network Volume (50GB)
✅ FLUX.1-dev model cache: 32GB in `/workspace/.cache`
✅ Python environment: 7.9GB in `/workspace/.venv`
✅ Scripts: `/workspace/scripts/generate.py`
✅ Generated images: `/workspace/outputs/`

## When You Restart Tomorrow

### 1. Start the RunPod Pod
- Go to RunPod dashboard
- Click your pod
- Click "Start" or create new pod with same network volume

### 2. Update Connection Info (AUTOMATED!)

**Option A: Automatic (recommended)** 🚀
```bash
cd ~/flux-image-generator
source config.env
bash scripts/update-pod-connection.sh
```
This automatically fetches the new IP/port and updates config.env for you!

**Option B: Manual (if automatic fails)**
```bash
nano ~/flux-image-generator/config.env
```
Update these two lines:
```
RUNPOD_HOST=<NEW_IP>
RUNPOD_PORT=<NEW_PORT>
```
Save (Ctrl+O, Enter, Ctrl+X)

### 3. Generate Your First Image
```bash
cd ~/flux-image-generator
bash flux-generate.sh "sunset over mountains" --fast --enhance-ai
```

## What Works Now
✅ FLUX.1-dev model (VRAM-only with CPU offload for memory management)
✅ Claude API prompt enhancement with 77-token CLIP trimming
✅ Quality presets: --fast (4 steps), --balanced (20), --quality (50)
✅ Auto-download to Windows and open in Photos viewer
✅ Full error reporting (no silent failures)

## Known Issues - NONE
Everything is working as it was before today's session.

## Files Location
- **WSL**: `~/flux-image-generator/`
- **Windows**: `C:\Users\rbsmi\Pictures\FLUX\`

## Quick Test Commands
```bash
# Fast generation (4 steps, ~10 sec)
bash flux-generate.sh "mountain landscape" --fast --enhance-ai

# Balanced quality (20 steps, ~30 sec)
bash flux-generate.sh "ocean waves" --balanced --enhance-ai

# High quality (50 steps, ~60 sec)
bash flux-generate.sh "forest path" --quality --enhance-ai
```

## If Issues Tomorrow
1. Verify SSH connection works
2. Check disk space: `ssh root@<IP> -p <PORT> -i ~/.ssh/id_ed25519 "df -h /workspace"`
3. Model should already be cached - no download needed

## Cost
- **While running**: ~$0.50/hour (RTX 4090)
- **While stopped**: $5/month (50GB storage only)
