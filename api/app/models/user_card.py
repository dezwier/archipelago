"""
UserCard model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
from app.models.enums import UserCardStatus


class UserCard(SQLModel, table=True):
    """UserCard table - tracks user's progress with specific lemmas."""
    __tablename__ = "user_cards"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    lemma_id: int = Field(foreign_key="lemma.id")
    image_path: Optional[str] = None
    created_time: datetime = Field(default_factory=datetime.utcnow)
    last_success_time: Optional[datetime] = None
    status: UserCardStatus = Field(default=UserCardStatus.NEW)
    next_review_at: Optional[datetime] = None  # Calculated by SRS
    
    # Relationships
    user: "User" = Relationship(back_populates="user_cards")
    lemma: "Lemma" = Relationship(back_populates="user_cards")

