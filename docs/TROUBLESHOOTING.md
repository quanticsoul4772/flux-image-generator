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

### Container vs Network Volume

**Container Disk** (`/` filesystem):
- 10GB temporary storage
- **RESETS ON POD RESTART**
- Used for: OS, temporary files
- Check: `df -h /`

**Network Volume** (`/workspace`):
- 50GB persistent storage  
- **SURVIVES POD RESTARTS**
- Must contain: Model cache, scripts, outputs
- Check: `df -h /workspace`

### Model Cache Locations

**WRONG** (container, gets deleted):
```
/root/.cache/huggingface/
```

**RIGHT** (network volume, persists):
```
/workspace/.cache/hub/
```

**How to Fix**:
```bash
# Set HF_HOME in pod's .bashrc
echo 'export HF_HOME=/workspace/.cache' >> ~/.bashrc
source ~/.bashrc

# Verify in SSH command
export HF_HOME='/workspace/.cache'
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

### Out of Memory

**Error**:
```
OutOfMemoryError: CUDA out of memory. Tried to allocate 72.00 MiB. 
GPU 0 has a total capacity of 23.52 GiB of which 7.75 MiB is free.
```

**Cause**: FLUX.1-dev needs >24GB VRAM, RTX 4090 has exactly 24GB

**Solutions**:

1. **CPU Offloading** (already in generate.py):
```python
pipe.enable_model_cpu_offload()
```

2. **Reduce steps**:
```bash
bash flux-generate.sh "prompt" --fast  # 4 steps
bash flux-generate.sh "prompt" --balanced  # 20 steps
```

3. **Use quantized model** (future):
```
FLUX.1-dev-fp8  # 8-bit quantized, fits in 16GB
```

### Check GPU Status
```bash
nvidia-smi
```

Should show:
- GPU: NVIDIA GeForce RTX 4090
- Memory: 24564 MiB total
- Processes: None when idle

### Clear GPU Memory
```bash
# Kill Python processes
pkill -9 python

# Check again
nvidia-smi
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
