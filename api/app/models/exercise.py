"""
Exercise model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional
from datetime import datetime


class Exercise(SQLModel, table=True):
    """Exercise table - tracks exercise sessions."""
    __tablename__ = "exercise"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_lemma_id: int = Field(foreign_key="user_lemma.id")
    exercise_type: str  # Exercise type (e.g., "Match Info to Image", "Discovery", etc.)
    result: str  # Exercise result: 'success', 'hint', or 'fail'
    start_time: datetime
    end_time: datetime
    
    # Relationships
    user_lemma: "UserLemma" = Relationship(back_populates="exercises")

