"""
Shared utilities for asset directory management.
"""
import logging
from pathlib import Path
from typing import Optional, List

from app.core.config import settings

logger = logging.getLogger(__name__)


def get_assets_directory() -> Path:
    """
    Get the assets directory path.
    
    Uses ASSETS_PATH environment variable if set (for Railway volumes),
    otherwise falls back to api/assets directory.
    
    Returns:
        Path to the assets directory
    """
    # Check if ASSETS_PATH is configured (for Railway volumes)
    if settings.assets_path:
        assets_dir = Path(settings.assets_path)
    else:
        # Fallback to API root/assets for local development
        # Calculate path relative to this file: utils/assets_utils.py -> api/app/utils/assets_utils.py
        # Go up 3 levels: utils -> app -> api, then into assets
        api_root = Path(__file__).parent.parent.parent.parent
        assets_dir = api_root / "assets"
    
    return assets_dir


def ensure_assets_directory(subdirectories: Optional[List[str]] = None) -> Path:
    """
    Ensure the assets directory exists and return its path.
    
    Optionally creates subdirectories within the assets directory.
    
    Args:
        subdirectories: Optional list of subdirectory names to create (e.g., ["audio", "images"])
    
    Returns:
        Path to the assets directory
    """
    assets_dir = get_assets_directory()
    
    # Ensure main directory exists
    assets_dir.mkdir(parents=True, exist_ok=True)
    
    # Ensure subdirectories exist if specified
    if subdirectories:
        for subdir in subdirectories:
            subdir_path = assets_dir / subdir
            subdir_path.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"Using assets directory: {assets_dir}")
    return assets_dir

