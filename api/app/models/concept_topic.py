"""
ConceptTopic model - junction table for many-to-many relationship between concepts and topics.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.concept import Concept
    from app.models.topic import Topic


class ConceptTopic(SQLModel, table=True):
    """ConceptTopic junction table - allows concepts to belong to multiple topics."""
    __tablename__ = "concept_topic"
    
    concept_id: int = Field(foreign_key="concept.id", primary_key=True)
    topic_id: int = Field(foreign_key="topic.id", primary_key=True)
    
    # Relationships
    concept: "Concept" = Relationship(back_populates="concept_topics")
    topic: "Topic" = Relationship(back_populates="concept_topics")

