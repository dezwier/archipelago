"""
Topic schemas.
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    user_id: int
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CreateTopicRequest(BaseModel):
    """Request schema for creating a topic."""
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    user_id: int


class UpdateTopicRequest(BaseModel):
    """Request schema for updating a topic."""
    name: Optional[str] = None
    description: Optional[str] = None
    icon: Optional[str] = None


class TopicsResponse(BaseModel):
    """Response schema for topics list."""
    topics: List[TopicResponse]

