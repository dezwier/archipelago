"""
UserPractice model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional
from datetime import datetime


class UserPractice(SQLModel, table=True):
    """UserPractice table - tracks practice sessions."""
    __tablename__ = "user_practices"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    created_time: datetime = Field(default_factory=datetime.utcnow)
    success: bool
    feedback: Optional[int] = None  # User feedback score
    
    # Relationships
    user: "User" = Relationship(back_populates="practices")

