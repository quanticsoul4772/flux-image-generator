#!/usr/bin/env python3
"""
Centralized configuration for FLUX image generator.

Loads default values from config_defaults.yaml and allows environment variable overrides.
"""

import os
import yaml
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class PathConfig:
    """RunPod path configuration"""
    workspace: str = "/workspace"
    cache: str = "/workspace/.cache"
    venv: str = "/workspace/.venv"
    scripts: str = "/workspace/scripts"
    outputs: str = "/workspace/outputs"
    hf_cache: str = "/workspace/.cache/huggingface"

    def __post_init__(self):
        """Expand paths based on workspace root"""
        if not self.cache.startswith('/'):
            self.cache = f"{self.workspace}/{self.cache}"
        if not self.venv.startswith('/'):
            self.venv = f"{self.workspace}/{self.venv}"
        if not self.scripts.startswith('/'):
            self.scripts = f"{self.workspace}/{self.scripts}"
        if not self.outputs.startswith('/'):
            self.outputs = f"{self.workspace}/{self.outputs}"
        if not self.hf_cache.startswith('/'):
            self.hf_cache = f"{self.workspace}/{self.hf_cache}"


@dataclass
class GenerationConfig:
    """Image generation parameters"""
    # Resolution defaults
    height: int = 1024
    width: int = 1024

    # Quality presets (inference steps)
    steps_fast: int = 4
    steps_balanced: int = 20
    steps_quality: int = 50

    # Guidance scale presets
    guidance_creative: float = 1.5
    guidance_default: float = 3.5
    guidance_strict: float = 5.0
    guidance_min: float = 1.0
    guidance_max: float = 7.0

    # Other parameters
    max_sequence_length: int = 512
    jpeg_quality: int = 95
    random_seed: bool = True  # If False, uses fixed_seed
    fixed_seed: int = 42

    # Model
    model_id: str = "black-forest-labs/FLUX.1-dev"
    torch_dtype: str = "bfloat16"  # bfloat16 or float16

    def __post_init__(self):
        """Validate configuration"""
        if self.guidance_min >= self.guidance_max:
            raise ValueError(f"guidance_min ({self.guidance_min}) must be < guidance_max ({self.guidance_max})")
        if not (1 <= self.jpeg_quality <= 100):
            raise ValueError(f"jpeg_quality must be 1-100, got {self.jpeg_quality}")
        if self.height <= 0 or self.width <= 0:
            raise ValueError(f"height and width must be positive, got {self.height}x{self.width}")


@dataclass
class ClaudeConfig:
    """Claude API configuration"""
    model: str = "claude-sonnet-4-5-20250929"
    max_tokens: int = 120
    temperature: float = 0.7
    timeout: int = 30
    system_prompt: str = "FLUX.1 enhancer. Under 50 words: subject, mood, camera (vary!), lighting, 8k. Return ONLY prompt."
    system_prompt_file: Optional[str] = "prompts/claude_system.txt"

    def __post_init__(self):
        """Load system prompt from file if it exists"""
        if self.system_prompt_file:
            # Path is relative to project root (one level up from config/)
            prompt_path = Path(__file__).parent.parent / self.system_prompt_file
            if prompt_path.exists():
                self.system_prompt = prompt_path.read_text().strip()

    def __setstate__(self, state):
        """Handle unpickling"""
        self.__dict__.update(state)


@dataclass
class HuggingFaceConfig:
    """HuggingFace API configuration for fallback enhancement"""
    model: str = "google/flan-t5-base"
    timeout: int = 30
    max_length: int = 150
    temperature: float = 0.7
    wait_for_model: bool = True


@dataclass
class CLIPConfig:
    """CLIP tokenizer configuration"""
    model: str = "openai/clip-vit-large-patch14"
    max_tokens: int = 77
    word_to_token_ratio: float = 1.6  # Fallback estimation when tokenizer unavailable

    def __post_init__(self):
        """Validate configuration"""
        if self.max_tokens <= 0:
            raise ValueError(f"max_tokens must be positive, got {self.max_tokens}")
        if self.word_to_token_ratio <= 0:
            raise ValueError(f"word_to_token_ratio must be positive, got {self.word_to_token_ratio}")


@dataclass
class SSHConfig:
    """SSH connection configuration"""
    connect_timeout: int = 10
    strict_host_key_checking: str = "accept-new"  # no, accept-new, yes
    compression: bool = True

    def __post_init__(self):
        """Validate configuration"""
        valid_options = ["no", "accept-new", "yes"]
        if self.strict_host_key_checking not in valid_options:
            raise ValueError(
                f"strict_host_key_checking must be one of {valid_options}, "
                f"got '{self.strict_host_key_checking}'"
            )


@dataclass
class Config:
    """Master configuration"""
    paths: PathConfig = field(default_factory=PathConfig)
    generation: GenerationConfig = field(default_factory=GenerationConfig)
    claude: ClaudeConfig = field(default_factory=ClaudeConfig)
    huggingface: HuggingFaceConfig = field(default_factory=HuggingFaceConfig)
    clip: CLIPConfig = field(default_factory=CLIPConfig)
    ssh: SSHConfig = field(default_factory=SSHConfig)

    @classmethod
    def load(cls, config_file: str = "config_defaults.yaml") -> "Config":
        """
        Load configuration from YAML file with environment variable overrides.

        Priority (highest to lowest):
        1. Environment variables
        2. YAML config file
        3. Dataclass defaults

        Args:
            config_file: Path to YAML configuration file

        Returns:
            Config instance
        """
        # Load from YAML if exists
        config_path = Path(__file__).parent / config_file
        if config_path.exists():
            with open(config_path) as f:
                data = yaml.safe_load(f) or {}
        else:
            data = {}

        # Create config objects with YAML data
        paths = PathConfig(**data.get('paths', {}))
        generation = GenerationConfig(**data.get('generation', {}))
        claude = ClaudeConfig(**data.get('claude', {}))
        huggingface = HuggingFaceConfig(**data.get('huggingface', {}))
        clip = CLIPConfig(**data.get('clip', {}))
        ssh = SSHConfig(**data.get('ssh', {}))

        return cls(
            paths=paths,
            generation=generation,
            claude=claude,
            huggingface=huggingface,
            clip=clip,
            ssh=ssh
        )

    def to_dict(self) -> dict:
        """Convert configuration to dictionary for serialization"""
        return {
            'paths': self.paths.__dict__,
            'generation': self.generation.__dict__,
            'claude': {k: v for k, v in self.claude.__dict__.items() if k != 'system_prompt'},
            'huggingface': self.huggingface.__dict__,
            'clip': self.clip.__dict__,
            'ssh': self.ssh.__dict__,
        }


# Global config instance - loaded once at import
config = Config.load()


if __name__ == "__main__":
    """Print current configuration"""
    import json
    print("Current Configuration:")
    print("=" * 60)
    print(json.dumps(config.to_dict(), indent=2))
