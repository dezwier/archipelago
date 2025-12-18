"""
Topics endpoint.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, status
from sqlmodel import Session, select
from typing import Optional
from app.core.database import get_session
from app.models.models import Topic
from app.schemas.topic import (
    TopicResponse,
    CreateTopicRequest,
    UpdateTopicRequest,
    TopicsResponse
)

router = APIRouter(prefix="/topics", tags=["topics"])


@router.get("", response_model=TopicsResponse)
async def get_topics(
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """Get topics, optionally filtered by user_id. Sorted by created_at descending (most recent first).
    When user_id is None (logged out), returns empty list since all topics belong to users."""
    if user_id is None:
        # When logged out, return empty list (no topics visible)
        return TopicsResponse(topics=[])
    
    query = select(Topic).where(Topic.user_id == user_id)
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
        icon=request.icon,
        user_id=request.user_id
    )
    session.add(topic)
    session.commit()
    session.refresh(topic)
    
    return TopicResponse.model_validate(topic)


@router.put("/{topic_id}", response_model=TopicResponse)
async def update_topic(
    topic_id: int,
    request: UpdateTopicRequest,
    session: Session = Depends(get_session)
):
    """Update a topic by ID."""
    topic = session.get(Topic, topic_id)
    if not topic:
        from fastapi import HTTPException
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topic not found")
    
    # Update fields if provided
    if request.name is not None:
        topic.name = request.name.lower().strip()
    if request.description is not None:
        topic.description = request.description if request.description.strip() else None
    if request.icon is not None:
        topic.icon = request.icon.strip() if request.icon.strip() else None
    
    session.add(topic)
    session.commit()
    session.refresh(topic)
    
    return TopicResponse.model_validate(topic)

