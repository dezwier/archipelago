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


class UserResponse(BaseModel):
    """User response schema (without password)."""
    id: int
    username: str
    email: str
    lang_native: str
    lang_learning: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """Authentication response schema."""
    user: UserResponse
    message: str

