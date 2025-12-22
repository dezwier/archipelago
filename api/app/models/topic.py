"""
Topic model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime


class Topic(SQLModel, table=True):
    """Topic table for grouping concepts."""
    __tablename__ = "topic"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None  # Single emoji character
    user_id: int = Field(foreign_key="user.id")  # User who created the topic (mandatory)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    concepts: List["Concept"] = Relationship(back_populates="topic")

