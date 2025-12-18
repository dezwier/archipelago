"""
Image model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, TYPE_CHECKING
from datetime import datetime

if TYPE_CHECKING:
    from app.models.concept import Concept


class Image(SQLModel, table=True):
    """Image table - stores images associated with concepts."""
    __tablename__ = "images"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    concept_id: int = Field(foreign_key="concept.id", index=True)
    url: str  # Image URL
    image_type: Optional[str] = None  # Type of image (e.g., 'illustration', 'photo', 'clipart')
    is_primary: bool = Field(default=False)  # Whether this is the primary image for the concept
    confidence_score: Optional[float] = None  # Confidence score for image relevance
    alt_text: Optional[str] = None  # Alt text for accessibility
    source: Optional[str] = None  # Source of the image (e.g., 'google', 'upload')
    licence: Optional[str] = None  # License information
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    concept: Optional["Concept"] = Relationship(back_populates="images")

