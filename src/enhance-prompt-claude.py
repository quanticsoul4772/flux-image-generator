#!/usr/bin/env python3
import sys, json, urllib.request, os

def count_clip_tokens(text):
    try:
        from transformers import CLIPTokenizer
        tok = CLIPTokenizer.from_pretrained("openai/clip-vit-large-patch14", use_fast=True)
        return len(tok.encode(text, add_special_tokens=True)), tok
    except:
        return int(len(text.split()) * 1.6), None

def trim_to_77(text):
    count, tok = count_clip_tokens(text)
    if count <= 77:
        return text
    if tok:
        tokens = tok.encode(text, add_special_tokens=True)
        return tok.decode(tokens[:77], skip_special_tokens=True)
    words = text.split()
    while len(words) > 48:
        words.pop()
    return " ".join(words)

key = os.environ.get("ANTHROPIC_API_KEY", "")
if len(sys.argv) < 2 or not key:
    sys.exit(1)

data = {
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 120,
    "temperature": 0.7,
    "system": "FLUX.1 enhancer. Under 50 words: subject, mood, camera (vary!), lighting, 8k. Return ONLY prompt.",
    "messages": [{"role": "user", "content": f"Enhance: {' '.join(sys.argv[1:])}"}]
}

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    json.dumps(data).encode(),
    {"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
)

with urllib.request.urlopen(req, timeout=30) as r:
    enhanced = json.loads(r.read())["content"][0]["text"].strip()

print(trim_to_77(enhanced))
