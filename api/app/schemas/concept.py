from __future__ import annotations

from pydantic import BaseModel, Field, computed_field, field_validator
from typing import Optional, List, TYPE_CHECKING
from datetime import datetime
from app.schemas.utils import normalize_part_of_speech

if TYPE_CHECKING:
    from app.schemas.lemma import LemmaResponse


class ImageResponse(BaseModel):
    """Image response schema."""
    id: int
    concept_id: int
    url: str
    image_type: Optional[str] = None
    is_primary: bool = False
    confidence_score: Optional[float] = None
    alt_text: Optional[str] = None
    source: Optional[str] = None
    licence: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ConceptResponse(BaseModel):
    """Concept response schema."""
    id: int
    topic_id: Optional[int] = None
    user_id: Optional[int] = None
    term: Optional[str] = None
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    level: Optional[str] = None  # CEFR level (A1, A2, B1, B2, C1, C2)
    frequency_bucket: Optional[str] = None
    status: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    images: Optional[List[ImageResponse]] = None
    
    # Backward compatibility: computed fields from images list
    @computed_field
    @property
    def image_path_1(self) -> Optional[str]:
        """Get first image URL for backward compatibility."""
        images = self.images
        if images is None or not images:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        # Return primary image first, or first image if no primary
        primary = next((img for img in images if img.is_primary), None)  # type: ignore[union-attr]
        if primary:
            return primary.url
        return images[0].url if images else None
    
    @computed_field
    @property
    def image_path_2(self) -> Optional[str]:
        """Get second image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 2:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        # Skip primary if it's first, return second image
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if non_primary:
            return non_primary[0].url
        # If all are primary or only one image, return None
        return images[1].url if len(images) > 1 else None
    
    @computed_field
    @property
    def image_path_3(self) -> Optional[str]:
        """Get third image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 3:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if len(non_primary) > 1:
            return non_primary[1].url
        # Fallback to third image overall
        return images[2].url if len(images) > 2 else None  # type: ignore[index]
    
    @computed_field
    @property
    def image_path_4(self) -> Optional[str]:
        """Get fourth image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 4:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if len(non_primary) > 2:
            return non_primary[2].url
        # Fallback to fourth image overall
        return images[3].url if len(images) > 3 else None  # type: ignore[index]

    class Config:
        from_attributes = True


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    description: Optional[str] = None
    user_id: int
    created_at: str

    class Config:
        from_attributes = True


class UpdateConceptImageRequest(BaseModel):
    """Request schema for updating a concept image."""
    image_url: str = Field(..., description="Image URL (can be empty string to clear)")

# Models for concept generation endpoint
class CreateConceptRequest(BaseModel):
    """Request schema for creating a concept with lemmas."""
    term: str = Field(..., min_length=1, description="The term to create a concept for")
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")
    part_of_speech: Optional[str] = Field(None, description="Part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence. If not provided, will be inferred from the term.")
    core_meaning_en: Optional[str] = Field(None, description="Core meaning in English")
    excluded_senses: Optional[List[str]] = Field(default=[], description="List of excluded senses")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate lemmas for")
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field if provided."""
        return normalize_part_of_speech(v)


class LLMConceptData(BaseModel):
    """Pydantic model for concept-level data from LLM."""
    description: str
    frequency_bucket: str
    
    @field_validator('frequency_bucket')
    @classmethod
    def validate_frequency_bucket(cls, v):
        """Validate frequency_bucket field."""
        valid_values = ['very high', 'high', 'medium', 'low', 'very low']
        if v not in valid_values:
            raise ValueError(f"frequency_bucket must be one of: {', '.join(valid_values)}. Got: {v}")
        return v


class CreateConceptOnlyRequest(BaseModel):
    """Request schema for creating only a concept (without cards)."""
    term: str = Field(..., min_length=1, description="The term")
    description: Optional[str] = Field(None, description="Description of the concept")
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")


class ConceptWithMissingLanguages(BaseModel):
    """Schema for a concept with missing languages."""
    concept: ConceptResponse
    missing_languages: List[str] = Field(..., description="List of language codes that are missing lemmas for this concept")


class ConceptsWithMissingLanguagesResponse(BaseModel):
    """Response schema for concepts with missing languages."""
    concepts: List[ConceptWithMissingLanguages]


class GetConceptsWithMissingLanguagesRequest(BaseModel):
    """Request schema for getting concepts with missing languages."""
    languages: List[str] = Field(..., min_items=1, description="List of language codes to check for missing cards")
    user_id: Optional[int] = Field(None, description="Optional user ID for prioritizing user's concepts in sorting")
    levels: Optional[List[str]] = Field(None, description="Optional list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by")
    part_of_speech: Optional[List[str]] = Field(None, description="Optional list of part of speech values to filter by")
    topic_ids: Optional[List[int]] = Field(None, description="Optional list of topic IDs to filter by")
    include_without_topic: bool = Field(False, description="Include concepts without a topic (topic_id is null)")
    include_public: bool = Field(True, description="Include public concepts (user_id is null)")
    include_private: bool = Field(True, description="Include private concepts (user_id == logged in user)")
    own_user_id: Optional[int] = Field(None, description="User ID for filtering private concepts (required if include_private is True)")
    search: Optional[str] = Field(None, description="Optional search query to filter by concept.term and lemma.term")


class GenerateCardsForConceptsRequest(BaseModel):
    """Request schema for generating lemmas for concepts."""
    concept_ids: List[int] = Field(..., min_items=1, description="List of concept IDs to generate lemmas for")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate lemmas for")
    user_id: Optional[int] = Field(None, description="Optional user ID for prioritizing user's concepts in sorting")


class GenerateCardsForConceptsResponse(BaseModel):
    """Response schema for generating lemmas for concepts."""
    concepts_processed: int = Field(..., description="Number of concepts processed")
    cards_created: int = Field(..., description="Total number of lemmas created")
    errors: List[str] = Field(default=[], description="List of error messages for concepts that failed")
    total_concepts: int = Field(..., description="Total number of concepts to process")
    session_cost_usd: float = Field(default=0.0, description="Total cost in USD for this generation session")
    total_tokens: int = Field(default=0, description="Total tokens used in this session")


class ConceptCountResponse(BaseModel):
    """Response schema for concept count endpoints."""
    count: int = Field(..., description="Total count of concepts")


# Schemas that reference both concepts and lemmas
# Using forward references to avoid circular imports
class CreateConceptResponse(BaseModel):
    """Response schema for concept creation."""
    concept: ConceptResponse
    cards: List[LemmaResponse]


class PairedVocabularyItem(BaseModel):
    """Paired vocabulary item - groups lemmas by concept."""
    concept_id: int
    cards: List[LemmaResponse] = Field(default=[], description="All lemmas for this concept")
    source_card: Optional[LemmaResponse] = None
    target_card: Optional[LemmaResponse] = None
    images: Optional[List[ImageResponse]] = None
    part_of_speech: Optional[str] = None
    concept_term: Optional[str] = None
    concept_description: Optional[str] = None
    concept_level: Optional[str] = None
    topic_name: Optional[str] = None
    topic_id: Optional[int] = None
    topic_description: Optional[str] = None
    
    # Backward compatibility: computed fields from images list
    @computed_field
    @property
    def image_path_1(self) -> Optional[str]:
        """Get first image URL for backward compatibility."""
        images = self.images
        if images is None or not images:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        primary = next((img for img in images if img.is_primary), None)  # type: ignore[union-attr]
        if primary:
            return primary.url
        return images[0].url if images else None  # type: ignore[index]
    
    @computed_field
    @property
    def image_path_2(self) -> Optional[str]:
        """Get second image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 2:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if non_primary:
            return non_primary[0].url
        return images[1].url if len(images) > 1 else None  # type: ignore[index]
    
    @computed_field
    @property
    def image_path_3(self) -> Optional[str]:
        """Get third image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 3:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if len(non_primary) > 1:
            return non_primary[1].url
        return images[2].url if len(images) > 2 else None  # type: ignore[index]
    
    @computed_field
    @property
    def image_path_4(self) -> Optional[str]:
        """Get fourth image URL for backward compatibility."""
        images = self.images
        if images is None or len(images) < 4:
            return None
        # Type narrowing: images is now List[ImageResponse]
        assert images is not None  # Type guard for linter
        non_primary = [img for img in images if not img.is_primary]  # type: ignore[union-attr]
        if len(non_primary) > 2:
            return non_primary[2].url
        return images[3].url if len(images) > 3 else None  # type: ignore[index]

    class Config:
        from_attributes = True


class VocabularyResponse(BaseModel):
    """Response schema for vocabulary endpoint."""
    items: List[PairedVocabularyItem]
    total: int = Field(..., description="Total number of items")
    page: int = Field(..., description="Current page number (1-indexed)")
    page_size: int = Field(..., description="Number of items per page")
    has_next: bool = Field(..., description="Whether there are more pages")
    has_previous: bool = Field(..., description="Whether there are previous pages")
    concepts_with_all_visible_languages: Optional[int] = Field(None, description="Count of concepts that have lemmas for all visible languages")
    total_concepts_with_term: Optional[int] = Field(None, description="Total number of concepts with at least a term (not affected by search)")


# Import at the end to resolve forward references at runtime
from app.schemas.lemma import LemmaResponse  # noqa: E402
