from pydantic_settings import BaseSettings
from typing import Optional
import os


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Database - Railway provides DATABASE_URL (uppercase)
    database_url: str = ""
    
    # API
    api_v1_prefix: str = "/api/v1"
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    class Config:
        env_file = ".env"
        case_sensitive = False
    
    def __init__(self, **kwargs):
        # Ensure we read DATABASE_URL from environment (Railway provides it uppercase)
        if not kwargs.get("database_url"):
            kwargs["database_url"] = os.getenv("DATABASE_URL", "")
        super().__init__(**kwargs)


# Create settings instance
settings = Settings()

# Fallback: if database_url is still empty, try reading DATABASE_URL directly
if not settings.database_url:
    settings.database_url = os.getenv("DATABASE_URL", "")

if not settings.database_url:
    raise ValueError("DATABASE_URL environment variable is required")
