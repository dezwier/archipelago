from pydantic_settings import BaseSettings
from typing import Optional
import os
from pathlib import Path

# Try to load .env file explicitly before creating Settings
try:
    from dotenv import load_dotenv
    import logging
    _logger = logging.getLogger(__name__)
    
    # Look for .env in api directory (parent of app directory)
    api_dir = Path(__file__).parent.parent.parent
    env_path = api_dir / ".env"
    
    if env_path.exists():
        load_dotenv(env_path, override=True)
        _logger.info(f"Loaded .env file from: {env_path}")
    else:
        # Fallback to current directory
        current_env = Path(".env")
        if current_env.exists():
            load_dotenv(current_env, override=True)
            _logger.info(f"Loaded .env file from: {current_env.absolute()}")
        else:
            _logger.warning(f".env file not found at {env_path} or {current_env.absolute()}")
except ImportError:
    # dotenv not installed, will rely on environment variables
    import logging
    _logger = logging.getLogger(__name__)
    _logger.warning("python-dotenv not installed. Install it with: pip install python-dotenv")
except Exception as e:
    import logging
    _logger = logging.getLogger(__name__)
    _logger.warning(f"Error loading .env file: {e}")


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Database - Railway provides DATABASE_URL (uppercase)
    database_url: str = ""
    
    # API
    api_v1_prefix: str = "/api/v1"
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    # Google Cloud Translation API
    google_translate_api_key: str = ""
    
    # Google Generative AI (Gemini) API
    google_gemini_api_key: str = ""
    
    class Config:
        env_file = ".env"
        case_sensitive = False
    
    def __init__(self, **kwargs):
        # Ensure we read DATABASE_URL from environment (Railway provides it uppercase)
        if not kwargs.get("database_url"):
            kwargs["database_url"] = os.getenv("DATABASE_URL", "")
        # Read Google API keys from environment (check both env var and .env file)
        if not kwargs.get("google_translate_api_key"):
            kwargs["google_translate_api_key"] = os.getenv("GOOGLE_TRANSLATE_API_KEY", "")
        if not kwargs.get("google_gemini_api_key"):
            kwargs["google_gemini_api_key"] = os.getenv("GOOGLE_GEMINI_API_KEY", "")
        super().__init__(**kwargs)


# Create settings instance
settings = Settings()

# Fallback: if database_url is still empty, try reading DATABASE_URL directly
if not settings.database_url:
    settings.database_url = os.getenv("DATABASE_URL", "")

if not settings.database_url:
    raise ValueError("DATABASE_URL environment variable is required")

# Fallback: if google_translate_api_key is still empty, try reading directly from environment
if not settings.google_translate_api_key:
    settings.google_translate_api_key = os.getenv("GOOGLE_TRANSLATE_API_KEY", "")
    # Also try uppercase version (some systems use uppercase env vars)
    if not settings.google_translate_api_key:
        settings.google_translate_api_key = os.getenv("GOOGLE_TRANSLATE_API_KEY", "")

# Fallback: if google_gemini_api_key is still empty, try reading directly from environment
if not settings.google_gemini_api_key:
    settings.google_gemini_api_key = os.getenv("GOOGLE_GEMINI_API_KEY", "")
