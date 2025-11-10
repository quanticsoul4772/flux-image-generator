# FLUX.1 [dev] Quick Start Guide

## Simple Usage (After Setup)

**Quick draft (default):**
```bash
cd ~/flux-image-generator
bash flux-generate.sh "a serene mountain landscape at golden hour"
```

**Better quality (recommended):**
```bash
bash flux-generate.sh "a serene mountain landscape at golden hour" --balanced
```

**Best quality:**
```bash
bash flux-generate.sh "a serene mountain landscape at golden hour" --quality
```

**Auto-enhanced prompts:**
```bash
bash flux-generate.sh "mountain sunset" --quality --enhance-ai
```

**Quality Presets:**
- `--fast` = 4 steps (~60s) - Quick drafts
- `--balanced` = 20 steps (~3min) - Good quality (recommended)
- `--quality` = 50 steps (~7min) - Best quality
- `--steps N` = Custom step count
- `--enhance-ai` = Use AI to expand your prompt with quality keywords

**What --enhance-ai does:**
- Uses Claude Sonnet 4.5 API to generate complete professional photography prompts
- Includes creative description + technical camera details in one AI-generated enhancement
- **Equipment varies based on shot type** - no hardcoded cameras!

**Examples:**

**Beach Sunset:**
```
Input: "beach sunset"
Output: "Golden hour beach sunset with vibrant orange and pink hues, waves gently 
lapping at shore... Shot on Nikon Z9 with 14-24mm f/2.8 lens at 18mm, f/16 for 
maximum depth, ISO 64, graduated ND filter, highly detailed, 8k uhd"
```

**Portrait:**
```
Input: "portrait of a woman"
Output: "Elegant portrait with piercing eyes and natural beauty, soft diffused 
lighting... Shot on Nikon Z9 with 105mm f/1.4 lens, f/2.0 for creamy bokeh, 
ISO 200, three-point lighting, 8k uhd, sharp focus on eyes"
```

**Cyberpunk City:**
```
Input: "cyberpunk city at night"
Output: "Neon-drenched cyberpunk metropolis, towering skyscrapers with holographic 
ads... Shot on Sony A7S III with 16-35mm f/2.8 at 24mm, f/4, ISO 3200 for 
low-light, long exposure for light trails, 8k uhd"
```

**Key Features:**
- ✅ Different cameras for different shots (Nikon Z9, Sony A7S III, Canon R5, Fuji X-T5, etc.)
- ✅ Contextually appropriate lenses (wide angle for landscapes, 85mm for portraits, etc.)
- ✅ Realistic settings (low ISO for bright scenes, high ISO for night, etc.)
- ✅ Professional techniques (ND filters, three-point lighting, long exposure, etc.)
- ✅ **No hardcoding - AI decides what equipment fits best**

That's it! Image generates, downloads, and opens automatically.

---

## First-Time Setup

## Prerequisites Checklist

- [ ] RunPod account created at https://runpod.io
- [ ] Credit added to RunPod account
- [ ] WSL installed and running on Windows
- [ ] SSH client available in WSL (should be pre-installed)
- [ ] HuggingFace account with FLUX.1-dev access approved
- [ ] HuggingFace token generated

## Step-by-Step Setup

### Step 1: Create RunPod Template (ONE TIME ONLY)

1. Go to RunPod dashboard → **"My Templates"** → **"New Template"**
2. Fill in template fields:
   - **Template Name**: `FLUX Generator`
   - **Container Image**: `runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04`
   - **Container Start Command**:
   ```bash
   bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server && mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGY+HBqPcceUM5gj70L6feJOhasU9IcR2dAw0m5GjOdV runpod-flux" > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && service ssh start && sleep infinity'
   ```
   - **Container Disk**: `50` GB
   - **Volume Disk**: `0` (leave blank)
   - **Volume Mount Path**: (leave blank)
   - **Expose TCP Ports**: `22`
   - **Environment Variables**: (leave blank)
3. Click **"Save Template"**

### Step 2: Deploy Pod

1. Click **"Deploy"** in RunPod
2. Select GPU: **RTX 4090** (24GB VRAM, ~$0.69/hr) or **A100/L40**
3. Select Template: **"FLUX Generator"**
4. Click **"Deploy On-Demand"**
5. Wait 2-3 minutes for pod to start and SSH to become ready

### Step 3: Get SSH Connection Details

1. In RunPod dashboard, click on your running pod
2. Click **"Connect"** tab
3. Scroll down to **"SSH over exposed TCP"** section
4. Find the connection like: `ssh root@157.157.221.29 -p 31546`
5. Note the **IP address** and **port number**

### Step 4: Configure Local Environment

```bash
cd ~/flux-image-generator
nano config.env
```

Update these lines with your pod's IP and port:
```bash
RUNPOD_HOST=157.157.221.29    # Your actual IP
RUNPOD_PORT=31546             # Your actual port
RUNPOD_USER=root
SSH_KEY=~/.ssh/id_ed25519
```

Save and exit (Ctrl+X, Y, Enter)

### Step 5: Restore HuggingFace Token

**CRITICAL: Do this BEFORE deploying!**

```bash
cd ~/flux-image-generator
ssh root@YOUR_IP -p YOUR_PORT -i ~/.ssh/id_ed25519 "mkdir -p ~/.cache/huggingface && echo 'YOUR_HF_TOKEN' > ~/.cache/huggingface/token"
```

Replace:
- `YOUR_IP` with your pod's IP
- `YOUR_PORT` with your pod's port  
- `YOUR_HF_TOKEN` with your HuggingFace token

### Step 6: Deploy FLUX Setup to RunPod

```bash
cd ~/flux-image-generator
bash scripts/deploy.sh
```

**What this does:**
- Tests SSH connection
- Uploads setup script to RunPod
- Installs Python environment
- **Downloads FLUX.1-dev model (24GB, takes 10-15 minutes)**
- Creates generation scripts

**Expected duration:** 15-20 minutes (first time only)

During deployment, watch for:
- ✓ SSH connection successful
- ✓ Python environment created
- ✓ PyTorch installed
- ✓ Model downloaded successfully
- ✓ Setup Complete!

### Step 7: Generate Your First Image

```bash
bash scripts/generate.sh "a photorealistic mountain landscape at sunrise"
```

This will:
1. Connect to RunPod
2. Generate the image (~45 seconds on RTX 4090)
3. Automatically download to `outputs/` directory

### Step 8: View Your Image

```bash
ls -lh outputs/
explorer.exe outputs/  # Opens in Windows
```

## CRITICAL WORKFLOW FOR EACH NEW POD

Every time you deploy a new pod, follow this exact order:

1. **Deploy pod** with FLUX Generator template
2. **Get IP and port** from Connect tab
3. **Update config.env** with new IP/port
4. **Restore HuggingFace token** (Step 5 above)
5. **Run deploy.sh** to download model
6. **Generate images**

**NEVER skip the token restoration step!** FLUX.1-dev requires authentication.

## Common Usage Patterns

### Batch Generation

```bash
nano prompts.txt  # Add prompts, one per line
bash scripts/generate.sh --batch prompts.txt
```

### Custom Parameters

Higher quality:
```bash
bash scripts/generate.sh "detailed portrait" --steps 50 --width 1536 --height 1024
```

Faster generation:
```bash
bash scripts/generate.sh "quick sketch" --steps 25 --width 768 --height 768
```

## Stopping and Restarting

### Stop Pod (saves money, data persists)

RunPod dashboard → Stop button

**Data persists** in container disk. When you restart:
- IP and port stay the same
- Model is already downloaded
- Token needs to be restored again
- No need to run deploy.sh again

### Terminate Pod (deletes everything)

Only when completely done. Next time you'll need to:
1. Deploy new pod with template
2. Follow full setup workflow again

## Troubleshooting

### "401 Unauthorized" during model download

**Problem**: HuggingFace token not set or invalid

**Fix**:
```bash
ssh root@YOUR_IP -p YOUR_PORT -i ~/.ssh/id_ed25519 "cat ~/.cache/huggingface/token"
```

If empty or wrong, restore it (Step 5)

### "Connection refused" error

**Check**:
1. Pod is running (green status)
2. TCP Port shows IP and port (not "Not Ready")
3. config.env has correct IP/port

### "CUDA out of memory"

**Solutions**:
- Smaller image: `--width 768 --height 768`
- Fewer steps: `--steps 25`
- Use GPU with 24GB+ VRAM

### Pod shows "Not Ready" for TCP Port

**Wait 2-3 minutes** after pod starts. If still not ready:
- Check Logs tab for errors
- Verify template has correct startup command
- Terminate and redeploy pod

## Cost Management

| GPU | Cost/Hour | 10 Images (~7.5 min) | 100 Images (~75 min) |
|-----|-----------|----------------------|----------------------|
| RTX 4090 | $0.69 | $0.09 | $0.86 |
| A100 40GB | $1.89 | $0.24 | $2.36 |
| RTX 3090 | $0.44 | $0.06 | $0.55 |

**Tips**:
- Use spot instances (50% cheaper)
- Batch generate multiple images
- Stop pod immediately after generating
- RTX 3090 is cheaper but slightly slower

## Template Troubleshooting

### Wrong Docker image error

If logs show "manifest not found":
- Template has wrong Container Image
- Must be: `runpod/pytorch:2.1.1-py3.10-cuda12.1.1-devel-ubuntu22.04`
- Note the version: `2.1.1` not `2.1.0`, `cuda12.1.1` not `cuda12.1.0`

### SSH never becomes ready

If TCP Port stays "Not Ready" for >5 minutes:
- Startup command likely failed
- Check Logs tab
- Verify startup command is correct (see Step 1)
- Terminate pod and redeploy with correct template

---

**Ready to create!** 🎨

Start with:
```bash
cd ~/flux-image-generator
bash scripts/generate.sh "a serene mountain landscape at golden hour"
```
