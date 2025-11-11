# FLUX LoRA Trainer

Train custom LoRA adapters for FLUX.1-dev using AI-Toolkit on RunPod GPU instances. Fine-tune the model for specific styles, subjects, or concepts using your own training images.

## Features

- **AI-Toolkit by Ostris**: Modern LoRA training framework optimized for FLUX models
- **FLUX.1-dev Support**: Native support for Black Forest Labs' FLUX.1-dev with quantization
- **RunPod Integration**: Remote training on A100 80GB GPUs via SSH
- **Network Volume Storage**: Persistent storage for models, datasets, and outputs
- **YAML Configuration**: Clean, version-controlled training configs
- **Multi-Resolution Training**: Automatic bucketing for [512, 768, 1024] resolutions

## Quick Start

### Prerequisites

- RunPod account with credit
- HuggingFace account with FLUX.1-dev access
- WSL/Linux/Mac with SSH
- Training dataset (100-1000+ images with captions)

### Critical First Step: Configure Storage

Before any training, set up cache symlink to avoid filling container storage:

```bash
ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP>
rm -rf /root/.cache
ln -sfn /workspace/.cache /root/.cache
ls -lah /root/ | grep cache  # verify symlink exists
```

This prevents downloads from filling the 10GB container root.

### 1. Update Connection Info

After deploying RunPod pod, update connection details in `config.env`:

```bash
cd ~/flux-image-generator
nano config.env
```

Update:
```bash
RUNPOD_HOST=<your_pod_ip>
RUNPOD_PORT=<your_pod_port>
HUGGINGFACE_TOKEN=<your_hf_token>
```

### 2. Verify Setup

Before training, verify all resources are in place:

```bash
ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP>

# Check dataset exists
ls /workspace/datasets/landscapes/*.jpg | wc -l

# Check FLUX model cached (should show ~32GB)
du -sh /workspace/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-dev

# Verify AI-Toolkit installation
ls /workspace/ai-toolkit/run.py

# Check PyTorch/CUDA
cd /workspace/ai-toolkit && source venv/bin/activate
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0)}')"
```

### 3. HuggingFace Authentication

FLUX.1-dev is a gated model requiring authentication:

```bash
cd /workspace/ai-toolkit && source venv/bin/activate
huggingface-cli login --token <your_hf_token>
```

Token is saved to `/workspace/.cache/huggingface/token` (persists on network volume).

### 4. Create Training Configuration

Edit or create YAML config in `/workspace/ai-toolkit/config/<your_config>.yaml`:

```yaml
job: extension
config:
  name: my_lora
  process:
    - type: sd_trainer
      training_folder: /workspace/training/output
      device: cuda:0

      model:
        name_or_path: black-forest-labs/FLUX.1-dev
        is_flux: true
        quantize: true

      network:
        type: lora
        linear: 16
        linear_alpha: 16

      datasets:
        - folder_path: /workspace/datasets/my_dataset
          caption_ext: txt
          caption_type: filename
          resolution: [512, 768, 1024]
          batch_size: 1

      train:
        steps: 2000
        gradient_accumulation_steps: 4
        train_unet: true
        train_text_encoder: false
        learning_rate: 1e-4
        lr_scheduler: constant
        optimizer: adamw8bit
        save_every: 500
        sample_every: 250

      save:
        dtype: float16
        save_every: 500
        max_step_saves_to_keep: 3
```

### 5. Run Training

With proper environment variables for GPU and cache:

```bash
cd /workspace/ai-toolkit && source venv/bin/activate
export CUDA_VISIBLE_DEVICES=0
export HF_HOME=/workspace/.cache/huggingface
export TMPDIR=/workspace/tmp
export TRANSFORMERS_CACHE=/workspace/.cache/huggingface
python run.py config/<your_config>.yaml 2>&1 | tee /workspace/training_output.log
```

Monitor in another terminal:
```bash
ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP> "tail -f /workspace/training_output.log"
```

Check GPU utilization:
```bash
ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP> nvidia-smi
```

## Project Structure

```
~/flux-image-generator/              # WSL local repo
├── config.env                       # Connection config (not in git)
├── landscape_lora.yaml              # Training config examples
└── README.md                        # This file

/workspace/                          # RunPod network volume (persistent)
├── .cache/                          # HuggingFace cache
│   └── huggingface/
│       ├── hub/
│       │   └── models--black-forest-labs--FLUX.1-dev/  # 32GB model cache
│       └── token                    # HuggingFace auth token
├── ai-toolkit/                      # AI-Toolkit installation
│   ├── run.py                       # Main training script
│   ├── config/                      # Training configurations
│   │   ├── landscape_lora.yaml
│   │   └── test_run.yaml
│   └── venv/                        # Python environment
├── datasets/                        # Training datasets
│   └── landscapes/                  # Example: 1000 landscape images
│       ├── image_001.jpg
│       ├── image_001.txt            # Caption for image_001.jpg
│       └── ...
└── training/                        # Training outputs
    └── output/
        └── my_lora/
            ├── my_lora.safetensors            # Final LoRA weights
            ├── my_lora_000000500.safetensors  # Checkpoint at step 500
            └── optimizer.pt                   # Optimizer state

Container Root (/)                   # 10GB ephemeral, resets on restart
└── root/
    └── .cache -> /workspace/.cache  # Symlink to network volume (critical!)
```

## Configuration

### RunPod Setup

**GPU Requirements**:
- Minimum: 24GB VRAM (RTX 4090, A5000)
- Recommended: A100 80GB for batch training
- Storage: 50GB network volume

**Cost**:
- **Compute**: ~$1.89/hour (A100 80GB on-demand)
- **Storage**: $5/month (50GB network volume)
- **Typical training**: 1-3 hours = ~$2-6 per LoRA

### Training Settings

**Resolution**:
- 512x512: Fast training, lower quality
- 1024x1024: Standard, best quality/speed balance
- 1024x1536: High quality portraits/art

**Batch Size**:
- 1024x1024: batch_size=4
- 1024x1536: batch_size=2
- 512x512: batch_size=8+

**Steps**:
- Small dataset (50-100 images): 1000-1500 steps
- Medium dataset (100-300 images): 1500-2500 steps
- Large dataset (300+ images): 2000-4000 steps

## Common Issues and Solutions

### Critical: Container Storage Full

**Symptom**: "No space left on device" error during training

**Cause**: HuggingFace downloads to `/root/.cache` (10GB container) instead of `/workspace/.cache` (network volume)

**Fix**:
```bash
# Kill training process first
pkill -9 python

# Remove container cache
rm -rf /root/.cache

# Create symlink to network volume
ln -sfn /workspace/.cache /root/.cache

# Verify symlink
ls -lah /root/ | grep cache

# Check container disk space (should be <10% now)
df -h | grep overlay

# Re-authenticate to HuggingFace
cd /workspace/ai-toolkit && source venv/bin/activate
huggingface-cli login --token <your_hf_token>
```

**Prevention**: Always create the cache symlink BEFORE starting any training or model downloads.

### Training Using CPU Instead of GPU

**Symptom**: Training runs but GPU utilization shows 0% in `nvidia-smi`

**Cause**: Missing `CUDA_VISIBLE_DEVICES` environment variable

**Fix**: Always export GPU environment variables before training:
```bash
export CUDA_VISIBLE_DEVICES=0
export HF_HOME=/workspace/.cache/huggingface
export TMPDIR=/workspace/tmp
export TRANSFORMERS_CACHE=/workspace/.cache/huggingface
```

### 401 Unauthorized Error

**Symptom**: `GatedRepoError: 401 Client Error` when loading FLUX model

**Cause**: Missing or invalid HuggingFace token

**Fix**:
```bash
cd /workspace/ai-toolkit && source venv/bin/activate
huggingface-cli login --token <your_hf_token>
```

Token is saved to `/workspace/.cache/huggingface/token` and persists on network volume.

### Model Re-downloading Every Time

**Symptom**: FLUX model downloads again (32GB) even though it exists

**Cause**: `HF_HOME` not set or cache symlink missing

**Fix**:
```bash
# Verify cache exists
du -sh /workspace/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-dev

# Verify symlink exists
ls -lah /root/.cache

# If symlink missing, create it
ln -sfn /workspace/.cache /root/.cache

# Always export HF_HOME before training
export HF_HOME=/workspace/.cache/huggingface
```

### Background Processes from Old Pods

**Symptom**: Many orphaned bash/python processes running

**Cause**: Previous sessions left processes running on old pod IPs

**Fix**:
```bash
# Check for old processes
ps aux | grep python

# Kill all Python processes
pkill -9 python

# Or kill all background bash shells
pkill -9 bash
```

## Deployment Checklist for New Pod

When deploying a new RunPod pod, follow this exact order:

1. **Deploy pod** and wait for SSH to be ready
2. **Update config.env** with new IP/port from RunPod dashboard
3. **Configure storage FIRST**:
   ```bash
   ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP>
   rm -rf /root/.cache
   ln -sfn /workspace/.cache /root/.cache
   ```
4. **Verify network volume contents**:
   - Dataset: `ls /workspace/datasets/<your_dataset>/*.jpg | wc -l`
   - FLUX model: `du -sh /workspace/.cache/huggingface/hub/models--black-forest-labs--FLUX.1-dev`
   - AI-Toolkit: `ls /workspace/ai-toolkit/run.py`
5. **HuggingFace authentication**:
   ```bash
   cd /workspace/ai-toolkit && source venv/bin/activate
   huggingface-cli login --token <your_hf_token>
   ```
6. **Verify CUDA**:
   ```bash
   python -c "import torch; print(torch.cuda.is_available())"
   nvidia-smi
   ```
7. **Now you can start training**

Skip steps 3-6 at your own risk. The container storage will fill up and training will fail.

## Output

Trained LoRAs are saved to `/workspace/training/output/<lora_name>/`:

```bash
# List all trained LoRAs
ssh -p <PORT> -i ~/.ssh/id_ed25519 root@<IP> "ls -lh /workspace/training/output/"

# Download specific LoRA
scp -P <PORT> -i ~/.ssh/id_ed25519 root@<IP>:/workspace/training/output/my_lora/my_lora.safetensors ~/Downloads/

# Download all checkpoints for a LoRA
scp -P <PORT> -i ~/.ssh/id_ed25519 root@<IP>:/workspace/training/output/my_lora/*.safetensors ~/Downloads/
```

Use with ComfyUI, AUTOMATIC1111, or any FLUX-compatible interface.

## Documentation

- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and fixes
- [AI-Toolkit Documentation](https://github.com/ostris/ai-toolkit) - Full AI-Toolkit docs
- [FLUX Training Guide](https://civitai.com/articles/6776) - Community training tips
