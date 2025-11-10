# CRITICAL WORKFLOW - READ THIS FIRST

## Every New Pod Deployment - Follow This Order EXACTLY

### 1. Deploy Pod
- Use "FLUX Generator" template
- Wait 2-3 minutes for pod to start

### 2. Get Connection Info
- RunPod → Click pod → Connect tab
- Note IP address and port from "SSH over exposed TCP"

### 3. Update config.env
```bash
cd ~/flux-image-generator
nano config.env

# Update these:
RUNPOD_HOST=<YOUR_IP>
RUNPOD_PORT=<YOUR_PORT>
```

### 4. Restore HuggingFace Token **BEFORE** deploy.sh
```bash
ssh root@<YOUR_IP> -p <YOUR_PORT> -i ~/.ssh/id_ed25519 \
  "mkdir -p ~/.cache/huggingface && echo '<YOUR_HF_TOKEN>' > ~/.cache/huggingface/token"
```

**WHY**: FLUX.1-dev is gated and requires authentication. Skipping this causes 401 errors.

### 5. Deploy FLUX
```bash
bash scripts/deploy.sh
```

Wait 10-15 minutes for 24GB model download.

### 6. Generate Images
```bash
bash scripts/generate.sh "your prompt"
```

---

## Common Mistakes

### ❌ Running deploy.sh without restoring token first
**Result**: 401 Unauthorized error during model download
**Fix**: Always restore token BEFORE deploy.sh

### ❌ Using wrong Docker image version
**Template must have**: `runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04`
**NOT**: `2.1.0` or `cuda12.1.0` (those don't exist)

### ❌ Trying to connect before TCP Port is ready
**Wait**: 2-3 minutes after pod starts for IP/port to show

### ❌ CUDA out of memory errors
**Cause**: generate.py not using memory optimization
**MUST HAVE**: CPU offloading enabled in generation script:
```python
pipe.enable_model_cpu_offload()
pipe.enable_sequential_cpu_offload()
pipe.vae.enable_slicing()
pipe.vae.enable_tiling()
```
**MUST USE**: `torch.bfloat16` (NOT `torch.float16`)
**NEVER USE**: `.to('cuda')` - CPU offloading handles device placement

---

## Template Configuration

**Save this template in RunPod (one time only):**

**Name**: FLUX Generator (Persistent)

**Container Image**:
```
runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04
```

**Container Start Command**:
```bash
bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server && mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGY+HBqPcceUM5gj70L6feJOhasU9IcR2dAw0m5GjOdV runpod-flux" > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && service ssh start && sleep infinity'
```

**Settings**:
- Container Disk: 10 GB
- Volume Disk: 50 GB
- Volume Mount Path: /workspace
- TCP Ports: 22

**Cost**: $5/month when stopped (50GB × $0.10/GB/month)

**Why 50GB?** FLUX model (24GB) + PyTorch (8GB) + overhead = ~40GB needed

**What This Fixes**:
- First deployment: 15 min (downloads FLUX once to volume)
- Every restart: 30 sec (FLUX already on volume!)
- Terminate pod: $0/hour running cost
- Model persists forever on volume

---

## Next Deployments (After First Time)

**Every time you need to generate images:**

1. Deploy pod in RunPod
   - Use same template
   - Select existing volume: "flux-storage"
   - Wait 30 seconds for startup

2. Update config.env
   ```bash
   cd ~/flux-image-generator
   nano config.env
   # Update RUNPOD_HOST and RUNPOD_PORT
   ```

3. Generate images
   ```bash
   # Quick draft (4 steps, ~60s)
   bash flux-generate.sh "your prompt"
   
   # Better quality (20 steps, ~3min) - RECOMMENDED
   bash flux-generate.sh "your prompt" --balanced
   
   # Best quality (50 steps, ~7min)
   bash flux-generate.sh "your prompt" --quality
   ```

4. Terminate pod when done

**That's it!** No more 15-minute waits. Model is already on the volume.

---

## Quick Reference

**Current Pod Connection** (update after each deployment):
```
IP: ___________________
Port: _________________
```

**Token Restoration Command**:
```bash
ssh root@<IP> -p <PORT> -i ~/.ssh/id_ed25519 \
  "mkdir -p ~/.cache/huggingface && echo '<TOKEN>' > ~/.cache/huggingface/token"
```

**Deploy Command**:
```bash
cd ~/flux-image-generator && bash scripts/deploy.sh
```

**Generate Commands**:
```bash
# Quick draft (4 steps, ~60s)
bash flux-generate.sh "your prompt"

# Better quality (20 steps, ~3min)
bash flux-generate.sh "your prompt" --balanced

# Best quality (50 steps, ~7min)
bash flux-generate.sh "your prompt" --quality

# Auto-enhanced prompts (adds quality keywords automatically)
bash flux-generate.sh "mountain sunset" --quality --enhance-ai
```
