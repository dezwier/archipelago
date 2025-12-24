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
    image_url: Optional[str] = None  # URL of the concept's image
    is_phrase: bool = False  # True if concept is a phrase (user-created), False if it's a word (script-created)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field, converting deprecated values to None."""
        return normalize_part_of_speech(v)
    
    # Backward compatibility: computed field for image_path_1
    @computed_field
    @property
    def image_path_1(self) -> Optional[str]:
        """Get image URL for backward compatibility."""
        return self.image_url

    class Config:
        from_attributes = True


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    user_id: int
    created_at: str

    class Config:
        from_attributes = True


class UpdateConceptImageRequest(BaseModel):
    """Request schema for updating a concept image."""
    image_url: str = Field(..., description="Image URL (can be empty string to clear)")


class UpdateConceptRequest(BaseModel):
    """Request schema for updating a concept."""
    term: Optional[str] = Field(None, min_length=1, description="The term (cannot be empty if provided)")
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    topic_id: Optional[int] = None
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field, converting deprecated values to None."""
        return normalize_part_of_speech(v)


class GenerateImageRequest(BaseModel):
    """Request schema for generating a concept image."""
    concept_id: int = Field(..., description="The concept ID")
    term: Optional[str] = Field(None, description="The concept term (will use concept.term if not provided)")
    description: Optional[str] = Field(None, description="The concept description (will use concept.description if not provided)")
    topic_id: Optional[int] = Field(None, description="The topic ID (will use concept.topic_id if not provided)")
    topic_description: Optional[str] = Field(None, description="The topic description (will use topic.description if not provided)")


class GenerateImagePreviewRequest(BaseModel):
    """Request schema for generating an image preview without a concept."""
    term: str = Field(..., description="The term or phrase")
    description: Optional[str] = Field(None, description="The description")
    topic_description: Optional[str] = Field(None, description="The topic description")

# Models for concept generation endpoint
class CreateConceptRequest(BaseModel):
    """Request schema for creating a concept with lemmas."""
    term: str = Field(..., min_length=1, description="The term to create a concept for")
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")
    part_of_speech: Optional[str] = Field(None, description="Part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Numeral. If not provided, will be inferred from the term.")
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
    """Request schema for creating only a concept (without lemmas)."""
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
    languages: List[str] = Field(..., min_items=1, description="List of language codes to check for missing lemmas")
    user_id: Optional[int] = Field(None, description="Optional user ID for prioritizing user's concepts in sorting")
    levels: Optional[List[str]] = Field(None, description="Optional list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by")
    part_of_speech: Optional[List[str]] = Field(None, description="Optional list of part of speech values to filter by")
    topic_ids: Optional[List[int]] = Field(None, description="Optional list of topic IDs to filter by")
    include_without_topic: bool = Field(False, description="Include concepts without a topic (topic_id is null)")
    include_lemmas: bool = Field(False, description="Include lemmas (is_phrase is False)")
    include_phrases: bool = Field(True, description="Include phrases (is_phrase is True)")
    search: Optional[str] = Field(None, description="Optional search query to filter by concept.term and lemma.term")
    has_images: Optional[int] = Field(None, description="1 = include only concepts with images, 0 = include only concepts without images, null = include all")
    is_complete: Optional[int] = Field(None, description="1 = include only complete concepts, 0 = include only incomplete concepts, null = include all")


class GenerateLemmasForConceptsRequest(BaseModel):
    """Request schema for generating lemmas for concepts."""
    concept_ids: List[int] = Field(..., min_items=1, description="List of concept IDs to generate lemmas for")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate lemmas for")
    user_id: Optional[int] = Field(None, description="Optional user ID for prioritizing user's concepts in sorting")


class GenerateLemmasForConceptsResponse(BaseModel):
    """Response schema for generating lemmas for concepts."""
    concepts_processed: int = Field(..., description="Number of concepts processed")
    lemmas_created: int = Field(..., description="Total number of lemmas created")
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
    lemmas: List[LemmaResponse]


class PairedDictionaryItem(BaseModel):
    """Paired dictionary item - groups lemmas by concept."""
    concept_id: int
    lemmas: List[LemmaResponse] = Field(default=[], description="All lemmas for this concept")
    source_lemma: Optional[LemmaResponse] = None
    target_lemma: Optional[LemmaResponse] = None
    image_url: Optional[str] = None  # URL of the concept's image
    part_of_speech: Optional[str] = None
    concept_term: Optional[str] = None
    concept_description: Optional[str] = None
    concept_level: Optional[str] = None
    topic_name: Optional[str] = None
    topic_id: Optional[int] = None
    topic_description: Optional[str] = None
    topic_icon: Optional[str] = None
    
    # Backward compatibility: computed field for image_path_1
    @computed_field
    @property
    def image_path_1(self) -> Optional[str]:
        """Get image URL for backward compatibility."""
        return self.image_url

    class Config:
        from_attributes = True


class DictionaryResponse(BaseModel):
    """Response schema for dictionary endpoint."""
    items: List[PairedDictionaryItem]
    total: int = Field(..., description="Total number of items")
    page: int = Field(..., description="Current page number (1-indexed)")
    page_size: int = Field(..., description="Number of items per page")
    has_next: bool = Field(..., description="Whether there are more pages")
    has_previous: bool = Field(..., description="Whether there are previous pages")
    concepts_with_all_visible_languages: Optional[int] = Field(None, description="Count of concepts that have lemmas for all visible languages")
    total_concepts_with_term: Optional[int] = Field(None, description="Total number of concepts with at least a term (not affected by search)")


# Import at the end to resolve forward references at runtime
from app.schemas.lemma import LemmaResponse  # noqa: E402
