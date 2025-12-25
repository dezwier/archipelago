"""
UserTopic model - junction table for topic subscriptions.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.topic import Topic


class UserTopic(SQLModel, table=True):
    """UserTopic junction table - allows users to subscribe to topics."""
    __tablename__ = "user_topic"
    
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    topic_id: int = Field(foreign_key="topic.id", primary_key=True)
    
    # Relationships
    user: "User" = Relationship(back_populates="user_topics")
    topic: "Topic" = Relationship(back_populates="user_topics")

