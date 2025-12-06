from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Database
    database_url: str
    
    # API
    api_v1_prefix: str = "/api/v1"
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()

