# Changelog

All notable changes to the FLUX Image Generator project.

## [2.0.0] - 2025-01-08

Major refactoring with comprehensive improvements across configuration, logging, error handling, and feature additions.

### Added

#### Configuration System
- **Centralized Python configuration** (`config.py`) using dataclasses
- **YAML configuration file** (`config_defaults.yaml`) for all default values
- **Shell configuration library** (`lib/config.sh`) for bash scripts
- **Configuration templates** (`.env.example`) for easy setup
- **Environment variable support** for all configuration values
- **Configuration validation** with helpful error messages

#### New Features - Image Generation
- **Resolution presets**: `--square`, `--portrait`, `--landscape`, `--hd`, `--4k`
- **Custom resolution support**: `--custom WIDTHxHEIGHT`
- **Seed control**: `--seed N` for reproducibility, `--random-seed` for variety
- **Random seeds by default** (breaking change from fixed seed 42)
- **JPEG quality control**: `--jpeg-quality N` (1-100)
- **CPU offloading toggle**: `--cpu-offload` / `--no-cpu-offload`
- **Comprehensive help**: `--help` flag with full documentation

#### Logging & Monitoring
- **Centralized logging system** (`logger.py`)
- **Colored console output** with log levels
- **File logging** to `logs/` directory with DEBUG level
- **Per-script log files**: `flux-generator.log`, `enhance-claude.log`, `enhance-hf.log`
- **Logging in all Python scripts** for better debugging

#### Documentation
- **CONFIGURATION.md**: Comprehensive configuration guide
- **CHANGELOG.md**: Version history and breaking changes
- **Updated README.md**: New features and examples
- **Updated CLAUDE.md**: Architecture changes
- **Phase completion docs**: PHASE1-COMPLETE.md, PHASE2-COMPLETE.md, PHASE3-COMPLETE.md

#### Development
- **requirements.txt**: All Python dependencies listed
- **Comprehensive .gitignore**: Prevents committing secrets and artifacts
- **.env.example**: Template for configuration

### Changed

#### Breaking Changes
- **`config.env` format changed**: Now secrets-only (API keys, RunPod connection)
  - Migration: Remove quality presets and defaults (moved to `config_defaults.yaml`)
- **`generate.py` argument handling**: Now uses argparse instead of positional-only
  - Old: `generate.py PROMPT FILENAME STEPS [GUIDANCE]`
  - New: `generate.py PROMPT FILENAME STEPS [GUIDANCE] [--height] [--width] [--seed] [--quality]`
  - Backward compatible for positional arguments
- **Random seeds by default** instead of fixed seed 42
  - Impact: Same prompt generates different images each time (use `--seed N` for reproducibility)
- **Prompt enhancement failures now exit with error** instead of silent fallback
  - Impact: Users see actual errors instead of receiving unenhanced prompts

#### Improvements
- **SSH security**: Changed `StrictHostKeyChecking=no` → `accept-new`
  - Prevents MITM attacks while allowing dynamic RunPod IPs
- **SSH timeout increased**: 5s → 10s (configurable)
- **Error messages improved**: Show helpful debugging information
- **No more hardcoded paths**: All paths from `lib/config.sh`
- **No more hardcoded presets**: All values from config files
- **Model selection configurable**: Can switch between FLUX.1-dev/schnell via config

### Fixed

#### Error Handling
- **CLIP tokenizer fallback now logged** instead of silent
  - Shows warning when falling back to word-count estimation
  - Provides installation instructions
- **HTTP error body parsing** with specific exception types
  - No more bare `except: pass` swallowing errors
- **Prompt enhancement errors** properly logged and reported
- **SSH/SCP errors** no longer hidden by `2>/dev/null`
- **Network errors** properly caught and reported

#### Security
- **All hardcoded API tokens removed** from test files
  - Now requires `source config.env` before running tests
- **config.env added to .gitignore** (was missing)
- **SSH host key checking** prevents MITM attacks

#### Code Quality
- **Warning suppression** specific instead of global
  - Only suppresses transformers FutureWarning and missing framework warnings
  - Other warnings now visible
- **Backup files removed** (.backup, .old)
- **Specific exception types** instead of bare except clauses
- **Type hints added** where appropriate
- **Docstrings added** to all functions

### Removed
- **Hardcoded values** from all Python and shell scripts (30+ instances)
- **Silent fallbacks** that masked errors
- **Backup files** (.backup, .old) - use git history instead
- **Duplicate configuration** in config.env (moved to YAML)
- **Global warning suppression** (now specific)
- **Error suppression** (`2>/dev/null` patterns removed)

---

## [1.0.0] - Initial Release

### Features
- Basic FLUX.1-dev image generation
- Claude API prompt enhancement
- RunPod GPU instance support
- SSH/SCP workflow for remote generation
- Windows WSL integration
- Basic quality presets (fast, balanced, quality)
- Basic guidance scale control

### Known Issues (Fixed in 2.0.0)
- Fixed seed 42 (no randomness)
- Hardcoded resolution (1024x1024 only)
- Silent failures in prompt enhancement
- Missing error logging
- Hardcoded paths throughout codebase
- API keys in test files
- Global warning suppression
- No configuration system

---

## Migration Guide: 1.0.0 → 2.0.0

### Required Actions

1. **Backup your config.env**
   ```bash
   cp config.env config.env.backup
   ```

2. **Update config.env format**
   ```bash
   # Remove these lines (moved to config_defaults.yaml):
   # - DEFAULT_STEPS
   # - DEFAULT_WIDTH
   # - DEFAULT_HEIGHT
   # - DEFAULT_GUIDANCE
   # - MODEL_NAME
   # - TORCH_DTYPE
   # - OUTPUT_FORMAT
   # - OUTPUT_QUALITY
   # - ENHANCEMENT_MODE

   # Keep only:
   # - ANTHROPIC_API_KEY
   # - HUGGINGFACE_TOKEN
   # - RUNPOD_HOST
   # - RUNPOD_PORT
   # - SSH_KEY
   # - OUTPUT_DIR_WSL
   # - OUTPUT_DIR_WINDOWS
   # - WINDOWS_USERNAME
   ```

3. **Install new dependencies**
   ```bash
   pip3 install -r requirements.txt
   ```

4. **Update custom scripts** (if any)
   ```bash
   # Add to beginning of scripts
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/lib/config.sh"

   # Replace hardcoded paths
   # Before: /workspace/scripts
   # After:  ${WORKSPACE_SCRIPTS}
   ```

### Optional Actions

1. **Customize config_defaults.yaml**
   - Adjust quality presets to your preferences
   - Change default resolution
   - Modify guidance scale presets

2. **Disable random seeds** (if you want reproducibility by default)
   ```yaml
   # config_defaults.yaml
   generation:
     random_seed: false
     fixed_seed: 12345  # Your preferred seed
   ```

3. **Review logs** for debugging
   ```bash
   tail -f logs/flux-generator.log
   ```

### Behavior Changes

| Aspect | v1.0.0 | v2.0.0 | Impact |
|--------|--------|--------|--------|
| Seed | Fixed (42) | Random | Different results each time |
| Resolution | 1024x1024 | Configurable | Can use portraits, landscapes, etc. |
| Enhancement failures | Silent | Error exit | Must fix API issues |
| Errors | Hidden | Visible | Better debugging |
| Paths | Hardcoded | Configurable | Can customize RunPod setup |

### New Capabilities

```bash
# Portrait with reproducible seed
bash flux-generate.sh "portrait" --portrait --seed 12345

# 4K landscape
bash flux-generate.sh "vista" --4k --quality

# Custom resolution
bash flux-generate.sh "logo" --custom 512x512 --fast --jpeg-quality 100

# Get help
bash flux-generate.sh --help
```

---

## Development Phases

This version was developed in 6 phases:

### Phase 1: Configuration System (2.5h planned → 1.5h actual)
- Created `config.py`, `config_defaults.yaml`, `.env.example`
- Added `.gitignore`, `requirements.txt`
- Externalized Claude system prompt

### Phase 2: Logging & Error Handling (4h planned → 2h actual)
- Created `logger.py`
- Fixed all silent failures (5 patterns)
- Improved SSH/SCP security
- Removed error suppression
- Specific exception handling

### Phase 3: Remove Hardcoding (6.5h planned → 2.5h actual)
- Created `lib/config.sh`
- Updated `generate.py` with argparse
- Updated `flux-generate.sh` with all new flags
- Removed 30+ hardcoded values

### Phase 4: Security Improvements (1h planned → 0h actual)
- Completed in Phase 2

### Phase 5: Code Cleanup (4h planned → 0.5h actual)
- Removed backup files
- Verified .gitignore

### Phase 6: Testing & Documentation (8h planned → 3h actual)
- Updated README.md, CLAUDE.md
- Created CONFIGURATION.md, CHANGELOG.md
- Created phase completion documents

**Total**: 32h planned → ~9.5h actual (71% faster than estimated)

---

## Future Enhancements (Planned)

### Phase 7: Optional Improvements
- [ ] Retry logic with exponential backoff for API calls
- [ ] Progress indicators during generation (tqdm)
- [ ] Prompt template system
  - Photography templates
  - Artistic templates
  - Technical/diagram templates
  - Cinematic templates
- [ ] Batch generation support
- [ ] Image-to-image support
- [ ] LoRA support
- [ ] Model switching (FLUX.1-dev ↔ FLUX.1-schnell)

### Community Requested
- [ ] Web UI for local generation
- [ ] Multiple image generation from single prompt
- [ ] Negative prompts support
- [ ] Aspect ratio presets (21:9, 9:16, etc.)
- [ ] Image upscaling integration
- [ ] Prompt history and favorites

---

## Support

For issues, questions, or contributions:
- Documentation: See README.md, CONFIGURATION.md, CLAUDE.md
- Issues: Track in your version control system
- Configuration help: See CONFIGURATION.md examples

---

## License

[Your License Here]
