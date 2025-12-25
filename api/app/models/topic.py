"""
Topic model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List, TYPE_CHECKING
from datetime import datetime
from sqlalchemy import Column, String as SAString
from app.models.enums import TopicVisibility

if TYPE_CHECKING:
    from app.models.concept_topic import ConceptTopic
    from app.models.user_topic import UserTopic


class Topic(SQLModel, table=True):
    """Topic table for grouping concepts."""
    __tablename__ = "topic"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None  # Single emoji character
    created_by_user_id: int = Field(foreign_key="user.id")  # User who created the topic (mandatory)
    visibility: TopicVisibility = Field(
        default=TopicVisibility.PRIVATE,
        sa_column=Column(SAString, default=TopicVisibility.PRIVATE.value)
    )  # 'public' or 'private' - stored as string, converted to enum
    liked: int = Field(default=0)  # Number of likes
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    concept_topics: List["ConceptTopic"] = Relationship(back_populates="topic")
    user_topics: List["UserTopic"] = Relationship(back_populates="topic")

