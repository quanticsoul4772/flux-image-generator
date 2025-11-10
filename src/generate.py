#!/usr/bin/env python3
import sys
import os
import torch
from diffusers import FluxPipeline

def main():
    try:
        if len(sys.argv) < 4:
            print("ERROR: Usage: generate.py PROMPT FILENAME STEPS", file=sys.stderr)
            sys.exit(1)
        
        prompt = sys.argv[1]
        filename = sys.argv[2]
        steps = int(sys.argv[3])
        
        print(f"Generating: {prompt}", flush=True)
        print(f"Output: /workspace/outputs/{filename}", flush=True)
        print(f"Steps: {steps}", flush=True)
        
        hf_token = os.environ.get('HUGGINGFACE_TOKEN')
        if not hf_token:
            print("ERROR: HUGGINGFACE_TOKEN not set", file=sys.stderr)
            sys.exit(1)
        
        print("Loading FLUX.1-dev...", flush=True)
        pipe = FluxPipeline.from_pretrained(
            "black-forest-labs/FLUX.1-dev",
            torch_dtype=torch.bfloat16,
            token=hf_token
        )
        
        print("Enabling CPU offload...", flush=True)
        pipe.enable_model_cpu_offload()
        
        print("Generating image...", flush=True)
        image = pipe(
            prompt=prompt,
            height=1024,
            width=1024,
            num_inference_steps=steps,
            max_sequence_length=512,
            generator=torch.Generator("cpu").manual_seed(42)
        ).images[0]
        
        output_path = f"/workspace/outputs/{filename}"
        print(f"Saving to {output_path}...", flush=True)
        image.save(output_path, quality=95)
        print(f"SUCCESS: Saved {output_path}", flush=True)
        
    except Exception as e:
        print(f"FATAL ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
