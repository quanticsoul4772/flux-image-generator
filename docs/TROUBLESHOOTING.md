# Troubleshooting Guide

## SSH Command Issues

### Quoting Problems
**Issue**: Commands fail with "unexpected EOF" or "syntax error"

**Wrong**:
```bash
wsl bash -c "ssh root@host 'command with "quotes"'"
```

**Right**:
```bash
wsl ssh root@host -p PORT -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no command
```

**Best Practice**: Run commands directly in WSL bash, not through `wsl` wrapper

## Storage Issues

### Critical: Understanding RunPod Storage Architecture

**Container Root (/) - 10GB Ephemeral**:
- Temporary overlay filesystem
- Resets on pod restart
- Default location for Python packages, OS files
- DO NOT store models, datasets, or training outputs here
- Check usage: `df -h | grep overlay`

**Network Volume (/workspace) - Persistent**:
- Survives pod restarts and terminations
- Persists across different pod deployments
- Should contain: models, datasets, outputs, cache
- Check usage: `df -h | grep workspace`

### The Cache Symlink Problem (Most Common Failure)

By default, HuggingFace downloads to `~/.cache` which maps to `/root/.cache` on the container root.

**What happens without symlink**:
1. Training starts
2. HuggingFace downloads FLUX model (32GB) to `/root/.cache`
3. Container root fills to 100% (10GB limit)
4. Training fails with "No space left on device"
5. All cache is lost on pod restart

**Solution (MUST do before any training)**:
```bash
# Remove existing container cache if any
rm -rf /root/.cache

# Create symlink to network volume
ln -sfn /workspace/.cache /root/.cache

# Verify symlink exists
ls -lah /root/ | grep cache
# Should show: lrwxrwxrwx 1 root root 17 ... .cache -> /workspace/.cache

# Check container disk (should be <10% after symlink)
df -h | grep overlay
```

### Model Cache Locations

**Wrong (container, gets deleted)**:
```
/root/.cache/huggingface/
~/.cache/huggingface/
```

**Right (network volume, persists)**:
```
/workspace/.cache/huggingface/
```

**Environment Variables to Set**:
```bash
export HF_HOME=/workspace/.cache/huggingface
export TRANSFORMERS_CACHE=/workspace/.cache/huggingface
export TMPDIR=/workspace/tmp
```

### Disk Full Errors

**Check what's using space**:
```bash
# Container
du -sh /* 2>/dev/null | sort -h

# Network volume
du -sh /workspace/*
du -h /workspace/.cache --max-depth=2
```

**Clean up**:
```bash
# Remove container cache
rm -rf /root/.cache

# Clean pip cache
pip cache purge

# Remove old images (keep last 5)
cd /workspace/outputs
ls -t | tail -n +6 | xargs rm -f
```

## CUDA/GPU Issues

### Training Using CPU Instead of GPU

**Symptom**: Training runs but `nvidia-smi` shows 0% GPU utilization

**Cause**: Missing `CUDA_VISIBLE_DEVICES` environment variable or PyTorch not detecting GPU

**Diagnosis**:
```bash
# Check if CUDA is available
cd /workspace/ai-toolkit && source venv/bin/activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'Device count: {torch.cuda.device_count()}')"

# Check GPU during training
nvidia-smi
# Look for python processes in GPU memory column
```

**Fix**:
```bash
# Always set these environment variables before training
export CUDA_VISIBLE_DEVICES=0
export HF_HOME=/workspace/.cache/huggingface
export TMPDIR=/workspace/tmp
export TRANSFORMERS_CACHE=/workspace/.cache/huggingface

# Then start training
cd /workspace/ai-toolkit && source venv/bin/activate
python run.py config/your_config.yaml
```

### Out of Memory

**Error**:
```
OutOfMemoryError: CUDA out of memory. Tried to allocate 72.00 MiB.
GPU 0 has a total capacity of 23.52 GiB of which 7.75 MiB is free.
```

**Cause**: FLUX.1-dev needs >24GB VRAM for training

**Solutions**:
1. Use quantization (enabled in config: `quantize: true`)
2. Reduce batch size to 1
3. Use gradient accumulation instead of larger batches
4. Use A100 80GB GPU instead of smaller GPUs

### Check GPU Status
```bash
nvidia-smi

# Or for continuous monitoring
watch -n 1 nvidia-smi
```

Expected during training:
- GPU utilization: 90-100%
- Memory used: 20-30GB for A100 80GB with quantization
- Temperature: 40-60C
- Processes: python (AI-Toolkit training)

### Clear GPU Memory
```bash
# Kill all Python training processes
pkill -9 python

# Verify GPU cleared
nvidia-smi
# Should show 0 MB used
```

## Generation Failures

### Silent Failures

**Symptom**: Script completes but no image generated

**Check**:
1. Look for error messages in output
2. Verify file exists: `ls /workspace/outputs/`
3. Check exit codes: Script should show `ERROR: Generation failed with exit code X`

### Download Failures

**Error**: `scp: /workspace/outputs/flux_*.jpg: No such file or directory`

**Cause**: Generation failed before creating file

**Fix**: Check generation errors above the download step

## HuggingFace Issues

### 401 Unauthorized

**Error**: `GatedRepoError: 401 Client Error`

**Cause**: Missing or invalid HUGGINGFACE_TOKEN

**Fix**:
1. Get token: https://huggingface.co/settings/tokens
2. Accept FLUX.1-dev license: https://huggingface.co/black-forest-labs/FLUX.1-dev
3. Update config.env with token

### Cache Not Found

**Error**: Model downloading every time

**Cause**: HF_HOME not set or pointing to wrong location

**Fix**:
```bash
# In SSH command
export HF_HOME='/workspace/.cache'

# Verify cache exists
ls -la /workspace/.cache/hub/models--black-forest-labs--FLUX.1-dev
```

## Image Opening Issues

### File Not Found

**Error**: `Start-Process: This command cannot be run due to the error: The system cannot find the file specified`

**Cause**: Image didn't download or wrong path

**Fix**:
1. Check if image exists: `ls ~/flux-image-generator/outputs/`
2. Open manually: `explorer.exe ~/flux-image-generator/outputs/`

### Wrong Application

**Issue**: Opens in wrong app or File Explorer

**Cause**: Windows file associations

**Fix**: Change default app for .jpg files in Windows Settings

## Restart Issues

### Can't Connect After Restart

**Cause**: Pod gets new IP/port on restart

**Fix**:
1. Get new connection info from RunPod dashboard
2. Update config.env:
```bash
nano ~/flux-image-generator/config.env
# Update RUNPOD_HOST and RUNPOD_PORT
```

### Model Redownloading

**Symptom**: Model downloads again after restart

**Cause**: Model was in container storage, not network volume

**Fix**:
1. Delete container cache: `rm -rf /root/.cache`
2. Ensure HF_HOME set: `export HF_HOME='/workspace/.cache'`
3. Model should be at: `/workspace/.cache/hub/`

## Diagnostic Commands

**Check disk space**:
```bash
df -h
du -sh /workspace
du -sh /workspace/*
```

**Check model location**:
```bash
find / -name "*FLUX*" -type d 2>/dev/null
du -h /workspace/.cache --max-depth=2
```

**Check GPU**:
```bash
nvidia-smi
```

**Check environment**:
```bash
echo $HF_HOME
echo $HUGGINGFACE_TOKEN
printenv | grep HF
```

**Test generation directly**:
```bash
cd /workspace
source .venv/bin/activate
export HF_HOME='/workspace/.cache'
export HUGGINGFACE_TOKEN='your_token'
python3 scripts/generate.py "test" "test.jpg" 4 3.5
```
