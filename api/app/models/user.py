"""
User model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
import hashlib


class User(SQLModel, table=True):
    """User table - stores user information."""
    __tablename__ = "users"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)  # Unique username
    email: str = Field(unique=True, index=True)  # Email address
    password: str  # Hashed password
    lang_native: str  # Native language code
    lang_learning: str  # Learning language code
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    cards: List["Card"] = Relationship(back_populates="user")
    practices: List["Practice"] = Relationship(back_populates="user")
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Simple password hashing using SHA256."""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password: str) -> bool:
        """Verify a password against the stored hash."""
        return self.password == self.hash_password(password)

