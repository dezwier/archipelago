"""
Concept model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
from app.models.enums import CEFRLevel


class Concept(SQLModel, table=True):
    """Concept table - represents a concept that can have multiple language cards."""
    __tablename__ = "concept"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    topic_id: Optional[int] = Field(default=None, foreign_key="topic.id")
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")  # User who created the concept (null for script-created concepts)
    term: str  # Former internal_name - English translation for the concept (mandatory)
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    frequency_bucket: Optional[str] = None
    level: Optional[CEFRLevel] = None  # CEFR language proficiency level (A1-C2)
    status: Optional[str] = None
    image_url: Optional[str] = None  # URL of the concept's image (max 1 image per concept)
    is_phrase: bool = Field(default=False)  # True if concept is a phrase (user-created), False if it's a word (script-created)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    
    # Relationships
    topic: Optional["Topic"] = Relationship(back_populates="concepts")
    lemmas: List["Lemma"] = Relationship(back_populates="concept")

