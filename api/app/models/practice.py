"""
Practice model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional
from datetime import datetime


class Practice(SQLModel, table=True):
    """Practice table - tracks practice sessions."""
    __tablename__ = "practices"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    card_id: int = Field(foreign_key="cards.id")
    created_time: datetime = Field(default_factory=datetime.utcnow)
    result: int  # Practice result score
    
    # Relationships
    user: "User" = Relationship(back_populates="practices")
    card: "Card" = Relationship(back_populates="practices")

