"""
Lesson model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List, TYPE_CHECKING
from datetime import datetime

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.language import Language
    from app.models.exercise import Exercise


class Lesson(SQLModel, table=True):
    """Lesson table - tracks lesson sessions."""
    __tablename__ = "lesson"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    learning_language: str = Field(foreign_key="languages.code", max_length=2)  # Learning language code
    kind: str  # Lesson kind: 'new', 'learned', or 'all'
    start_time: datetime
    end_time: datetime
    
    # Relationships
    user: "User" = Relationship(back_populates="lessons")
    language: "Language" = Relationship()
    exercises: List["Exercise"] = Relationship(back_populates="lesson")

