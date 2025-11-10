#!/usr/bin/env python3
"""
Centralized logging configuration for FLUX image generator.

Provides consistent logging across all Python scripts with both console
and optional file output.
"""

import logging
import sys
from pathlib import Path
from typing import Optional


class ColoredFormatter(logging.Formatter):
    """Colored console output formatter"""

    # ANSI color codes
    COLORS = {
        'DEBUG': '\033[36m',      # Cyan
        'INFO': '\033[32m',       # Green
        'WARNING': '\033[33m',    # Yellow
        'ERROR': '\033[31m',      # Red
        'CRITICAL': '\033[35m',   # Magenta
        'RESET': '\033[0m'        # Reset
    }

    def format(self, record):
        """Format log record with colors"""
        levelname = record.levelname
        if levelname in self.COLORS:
            record.levelname = f"{self.COLORS[levelname]}{levelname}{self.COLORS['RESET']}"
        return super().format(record)


def setup_logger(
    name: str,
    log_file: Optional[str] = None,
    level: int = logging.INFO,
    console_level: Optional[int] = None,
    file_level: Optional[int] = None,
    use_colors: bool = True
) -> logging.Logger:
    """
    Create logger with console and optional file output.

    Args:
        name: Logger name (usually __name__ or script name)
        log_file: Optional path to log file. If provided, logs are written to file.
        level: Default logging level (applies to both console and file if not specified)
        console_level: Override console logging level
        file_level: Override file logging level (defaults to DEBUG if file logging enabled)
        use_colors: Use colored output for console (default: True)

    Returns:
        Configured logger instance

    Example:
        >>> logger = setup_logger('my_script', log_file='logs/my_script.log')
        >>> logger.info("Processing started")
        >>> logger.warning("This is a warning")
        >>> logger.error("This is an error")
    """
    # Get or create logger
    logger = logging.getLogger(name)

    # Avoid duplicate handlers if logger already configured
    if logger.handlers:
        return logger

    logger.setLevel(logging.DEBUG)  # Capture all levels, handlers will filter
    logger.propagate = False

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(console_level if console_level is not None else level)

    if use_colors and sys.stdout.isatty():
        console_format = ColoredFormatter(
            '%(levelname)s: %(message)s'
        )
    else:
        console_format = logging.Formatter(
            '%(levelname)s: %(message)s'
        )
    console_handler.setFormatter(console_format)
    logger.addHandler(console_handler)

    # File handler (optional)
    if log_file:
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)

        file_handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
        file_handler.setLevel(file_level if file_level is not None else logging.DEBUG)
        file_format = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)

    return logger


def get_logger(name: str) -> logging.Logger:
    """
    Get existing logger or create new one with default settings.

    Args:
        name: Logger name

    Returns:
        Logger instance
    """
    logger = logging.getLogger(name)
    if not logger.handlers:
        return setup_logger(name)
    return logger


# Default logger for general use
logger = setup_logger('flux-generator', log_file='logs/flux-generator.log')


if __name__ == "__main__":
    """Test logging configuration"""
    print("Testing logging configuration:")
    print("=" * 60)

    # Test default logger
    logger.debug("This is a debug message (not shown by default)")
    logger.info("This is an info message")
    logger.warning("This is a warning message")
    logger.error("This is an error message")
    logger.critical("This is a critical message")

    print()
    print("Testing custom logger with DEBUG level:")
    print("=" * 60)

    # Test custom logger with debug enabled
    debug_logger = setup_logger('test', level=logging.DEBUG)
    debug_logger.debug("This is a debug message (shown)")
    debug_logger.info("This is an info message")
    debug_logger.warning("This is a warning message")
    debug_logger.error("This is an error message")

    print()
    print("Log file created at: logs/flux-generator.log")
    print("Check the file for detailed logging output with timestamps.")
