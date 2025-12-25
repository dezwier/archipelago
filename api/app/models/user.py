"""
User model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
import hashlib


class User(SQLModel, table=True):
    """User table - stores user information."""
    __tablename__ = "user"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)  # Unique username
    email: str = Field(unique=True, index=True)  # Email address
    password: str  # Hashed password
    lang_native: str  # Native language code
    lang_learning: str  # Learning language code
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Profile fields
    full_name: Optional[str] = Field(default=None)  # User's full name
    image_url: Optional[str] = Field(default=None)  # Profile image URL
    
    # Leitner algorithm configuration
    leitner_max_bins: int = Field(default=7)  # Maximum bins for Leitner algorithm
    leitner_algorithm: str = Field(default='fibonacci')  # Algorithm type
    leitner_interval_factor: Optional[float] = Field(default=None)  # Interval factor
    leitner_interval_start: int = Field(default=23)  # Starting interval in hours
    
    # Relationships
    user_lemmas: List["UserLemma"] = Relationship(back_populates="user")
    lessons: List["Lesson"] = Relationship(back_populates="user")
    user_topics: List["UserTopic"] = Relationship(back_populates="user")
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Simple password hashing using SHA256."""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password: str) -> bool:
        """Verify a password against the stored hash."""
        return self.password == self.hash_password(password)

