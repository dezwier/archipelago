"""
Topics endpoint.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Topic
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter(prefix="/topics", tags=["topics"])


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    
    class Config:
        from_attributes = True


class CreateTopicRequest(BaseModel):
    """Request schema for creating a topic."""
    name: str


class TopicsResponse(BaseModel):
    """Response schema for topics list."""
    topics: List[TopicResponse]


@router.get("", response_model=TopicsResponse)
async def get_topics(
    session: Session = Depends(get_session)
):
    """Get all topics."""
    topics = session.exec(select(Topic)).all()
    return TopicsResponse(
        topics=[TopicResponse.model_validate(topic) for topic in topics]
    )


@router.post("", response_model=TopicResponse, status_code=status.HTTP_201_CREATED)
async def create_topic(
    request: CreateTopicRequest,
    session: Session = Depends(get_session)
):
    """Create a new topic or return existing one if it already exists."""
    topic_name_lower = request.name.lower().strip()
    
    # Check if topic already exists
    existing_topic = session.exec(
        select(Topic).where(Topic.name.ilike(topic_name_lower))
    ).first()
    
    if existing_topic:
        return TopicResponse.model_validate(existing_topic)
    
    # Create new topic
    topic = Topic(name=topic_name_lower)
    session.add(topic)
    session.commit()
    session.refresh(topic)
    
    return TopicResponse.model_validate(topic)

