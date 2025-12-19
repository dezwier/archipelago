"""
Card model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime


class Card(SQLModel, table=True):
    """Card table - tracks user's progress with specific lemmas."""
    __tablename__ = "cards"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    lemma_id: int = Field(foreign_key="lemma.id")
    created_time: datetime = Field(default_factory=datetime.utcnow)
    last_success_time: Optional[datetime] = None
    leitner_bin: int = Field(default=0)
    next_review_at: Optional[datetime] = None  # Calculated by SRS
    
    # Relationships
    user: "User" = Relationship(back_populates="cards")
    lemma: "Lemma" = Relationship(back_populates="cards")
    practices: List["Practice"] = Relationship(back_populates="card")

