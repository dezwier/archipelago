from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class LoginRequest(BaseModel):
    """Login request schema."""
    username: str = Field(..., description="Username or email")
    password: str = Field(..., min_length=1, description="Password")


class RegisterRequest(BaseModel):
    """Registration request schema."""
    username: str = Field(..., min_length=3, max_length=50, description="Username")
    email: EmailStr = Field(..., description="Email address")
    password: str = Field(..., min_length=6, description="Password (minimum 6 characters)")
    native_language: str = Field(..., max_length=2, description="Native language code (e.g., 'en', 'fr')")
    learning_language: Optional[str] = Field(None, max_length=2, description="Learning language code (e.g., 'en', 'fr')")
    full_name: Optional[str] = Field(None, max_length=200, description="User's full name")


class UserResponse(BaseModel):
    """User response schema (without password)."""
    id: int
    username: str
    email: str
    lang_native: str
    lang_learning: Optional[str] = None
    created_at: str
    full_name: Optional[str] = None
    image_url: Optional[str] = None
    leitner_max_bins: int = 7
    leitner_algorithm: str = 'fibonacci'
    leitner_interval_factor: Optional[float] = None
    leitner_interval_start: int = 23

    class Config:
        from_attributes = True


class UpdateUserLanguagesRequest(BaseModel):
    """Update user languages request schema."""
    lang_native: Optional[str] = Field(None, max_length=2, description="Native language code (e.g., 'en', 'fr')")
    lang_learning: Optional[str] = Field(None, max_length=2, description="Learning language code (e.g., 'en', 'fr')")


class UpdateLeitnerConfigRequest(BaseModel):
    """Update Leitner configuration request schema."""
    leitner_max_bins: Optional[int] = Field(None, ge=5, le=20, description="Maximum bins for Leitner algorithm (5-20)")
    leitner_algorithm: Optional[str] = Field(None, description="Algorithm type (currently only 'fibonacci' supported)")
    leitner_interval_start: Optional[int] = Field(None, ge=1, le=24, description="Starting interval in hours (1-24)")


class AuthResponse(BaseModel):
    """Authentication response schema."""
    user: UserResponse
    message: str

