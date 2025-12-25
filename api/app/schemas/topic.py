"""
Topic schemas.
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.models.enums import TopicVisibility


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    created_by_user_id: int
    visibility: TopicVisibility = TopicVisibility.PRIVATE
    liked: int = 0
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CreateTopicRequest(BaseModel):
    """Request schema for creating a topic."""
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    user_id: int  # Keep as user_id for backward compatibility in API, maps to created_by_user_id
    visibility: Optional[TopicVisibility] = TopicVisibility.PRIVATE


class UpdateTopicRequest(BaseModel):
    """Request schema for updating a topic."""
    name: Optional[str] = None
    description: Optional[str] = None
    icon: Optional[str] = None
    visibility: Optional[TopicVisibility] = None


class TopicsResponse(BaseModel):
    """Response schema for topics list."""
    topics: List[TopicResponse]

