"""
Topics endpoint.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Topic
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter(prefix="/topics", tags=["topics"])


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    description: Optional[str] = None
    user_id: int
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class CreateTopicRequest(BaseModel):
    """Request schema for creating a topic."""
    name: str
    description: Optional[str] = None
    user_id: int


class TopicsResponse(BaseModel):
    """Response schema for topics list."""
    topics: List[TopicResponse]


@router.get("", response_model=TopicsResponse)
async def get_topics(
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """Get topics, optionally filtered by user_id. Sorted by created_at descending (most recent first)."""
    query = select(Topic)
    if user_id is not None:
        query = query.where(Topic.user_id == user_id)
    query = query.order_by(Topic.created_at.desc())  # type: ignore
    topics = session.exec(query).all()
    return TopicsResponse(
        topics=[TopicResponse.model_validate(topic) for topic in topics]
    )


@router.post("", response_model=TopicResponse, status_code=status.HTTP_201_CREATED)
async def create_topic(
    request: CreateTopicRequest,
    session: Session = Depends(get_session)
):
    """Create a new topic or return existing one if it already exists for this user."""
    topic_name_lower = request.name.lower().strip()
    
    # Check if topic already exists for this user
    existing_topic = session.exec(
        select(Topic).where(
            Topic.name.ilike(topic_name_lower),  # type: ignore[attr-defined]
            Topic.user_id == request.user_id
        )
    ).first()
    
    if existing_topic:
        return TopicResponse.model_validate(existing_topic)
    
    # Create new topic
    topic = Topic(
        name=topic_name_lower,
        description=request.description,
        user_id=request.user_id
    )
    session.add(topic)
    session.commit()
    session.refresh(topic)
    
    return TopicResponse.model_validate(topic)

