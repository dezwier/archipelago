"""
UserLemma model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime


class UserLemma(SQLModel, table=True):
    """UserLemma table - tracks user's progress with specific lemmas."""
    __tablename__ = "user_lemma"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    lemma_id: int = Field(foreign_key="lemma.id")
    created_time: datetime = Field(default_factory=datetime.utcnow)
    last_review_time: Optional[datetime] = None
    leitner_bin: int = Field(default=0)
    next_review_at: Optional[datetime] = None  # Calculated by SRS
    
    # Relationships
    user: "User" = Relationship(back_populates="user_lemmas")
    lemma: "Lemma" = Relationship(back_populates="user_lemmas")
    exercises: List["Exercise"] = Relationship(back_populates="user_lemma")

