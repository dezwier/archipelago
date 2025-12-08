from pydantic import BaseModel, Field, computed_field
from typing import Optional, List
from datetime import datetime


class GenerateFlashcardRequest(BaseModel):
    """Request schema for generating a flashcard."""
    concept: str = Field(..., min_length=1, description="The word or phrase to create a flashcard for")
    source_language: str = Field(..., max_length=2, description="Source language code (e.g., 'en', 'fr')")
    target_language: str = Field(..., max_length=2, description="Target language code (e.g., 'en', 'fr')")
    topic: Optional[str] = Field(None, description="Optional topic island name")


class CardResponse(BaseModel):
    """Card response schema."""
    id: int
    concept_id: int
    language_code: str
    translation: str
    description: str
    ipa: Optional[str] = None
    audio_path: Optional[str] = None
    gender: Optional[str] = None
    notes: Optional[str] = None

    class Config:
        from_attributes = True


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
    term: Optional[str] = None
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
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
        if not self.images:
            return None
        # Return primary image first, or first image if no primary
        primary = next((img for img in self.images if img.is_primary), None)
        if primary:
            return primary.url
        return self.images[0].url if self.images else None
    
    @computed_field
    @property
    def image_path_2(self) -> Optional[str]:
        """Get second image URL for backward compatibility."""
        if not self.images or len(self.images) < 2:
            return None
        # Skip primary if it's first, return second image
        non_primary = [img for img in self.images if not img.is_primary]
        if non_primary:
            return non_primary[0].url
        # If all are primary or only one image, return None
        return self.images[1].url if len(self.images) > 1 else None
    
    @computed_field
    @property
    def image_path_3(self) -> Optional[str]:
        """Get third image URL for backward compatibility."""
        if not self.images or len(self.images) < 3:
            return None
        non_primary = [img for img in self.images if not img.is_primary]
        if len(non_primary) > 1:
            return non_primary[1].url
        # Fallback to third image overall
        return self.images[2].url if len(self.images) > 2 else None
    
    @computed_field
    @property
    def image_path_4(self) -> Optional[str]:
        """Get fourth image URL for backward compatibility."""
        if not self.images or len(self.images) < 4:
            return None
        non_primary = [img for img in self.images if not img.is_primary]
        if len(non_primary) > 2:
            return non_primary[2].url
        # Fallback to fourth image overall
        return self.images[3].url if len(self.images) > 3 else None

    class Config:
        from_attributes = True


class TopicResponse(BaseModel):
    """Topic response schema."""
    id: int
    name: str
    created_at: str

    class Config:
        from_attributes = True


class GenerateFlashcardResponse(BaseModel):
    """Response schema for flashcard generation."""
    concept: ConceptResponse
    topic: Optional[TopicResponse] = None
    source_card: CardResponse
    target_card: CardResponse
    all_cards: List[CardResponse]  # All cards for this concept
    message: str


class PairedVocabularyItem(BaseModel):
    """Paired vocabulary item - groups source and target cards by concept."""
    concept_id: int
    source_card: Optional[CardResponse] = None
    target_card: Optional[CardResponse] = None
    images: Optional[List[ImageResponse]] = None
    
    # Backward compatibility: computed fields from images list
    @computed_field
    @property
    def image_path_1(self) -> Optional[str]:
        """Get first image URL for backward compatibility."""
        if not self.images:
            return None
        primary = next((img for img in self.images if img.is_primary), None)
        if primary:
            return primary.url
        return self.images[0].url if self.images else None
    
    @computed_field
    @property
    def image_path_2(self) -> Optional[str]:
        """Get second image URL for backward compatibility."""
        if not self.images or len(self.images) < 2:
            return None
        non_primary = [img for img in self.images if not img.is_primary]
        if non_primary:
            return non_primary[0].url
        return self.images[1].url if len(self.images) > 1 else None
    
    @computed_field
    @property
    def image_path_3(self) -> Optional[str]:
        """Get third image URL for backward compatibility."""
        if not self.images or len(self.images) < 3:
            return None
        non_primary = [img for img in self.images if not img.is_primary]
        if len(non_primary) > 1:
            return non_primary[1].url
        return self.images[2].url if len(self.images) > 2 else None
    
    @computed_field
    @property
    def image_path_4(self) -> Optional[str]:
        """Get fourth image URL for backward compatibility."""
        if not self.images or len(self.images) < 4:
            return None
        non_primary = [img for img in self.images if not img.is_primary]
        if len(non_primary) > 2:
            return non_primary[2].url
        return self.images[3].url if len(self.images) > 3 else None

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


class UpdateCardRequest(BaseModel):
    """Request schema for updating a card."""
    translation: Optional[str] = Field(None, min_length=1, description="Updated translation text")
    description: Optional[str] = Field(None, description="Updated description text")


class UpdateConceptImageRequest(BaseModel):
    """Request schema for updating a concept image."""
    image_url: str = Field(..., description="Image URL (can be empty string to clear)")


class GenerateDescriptionsResponse(BaseModel):
    """Response for starting description generation."""
    task_id: str = Field(..., description="Unique task ID for tracking progress")
    message: str = Field(..., description="Status message")
    total_concepts: int = Field(..., description="Total number of concepts that need descriptions")
    status: str = Field(..., description="Task status: 'running'")


class TaskStatusResponse(BaseModel):
    """Response for task status."""
    task_id: str = Field(..., description="Task ID")
    status: str = Field(..., description="Task status: 'running', 'completed', 'cancelled', 'failed', 'cancelling'")
    progress: dict = Field(..., description="Progress information including processed, total_concepts, cards_updated, etc.")
    message: Optional[str] = Field(None, description="Status message")


# Models for concept generation endpoint
class CreateConceptRequest(BaseModel):
    """Request schema for creating a concept with cards."""
    term: str = Field(..., min_length=1, description="The term to create a concept for")
    topic_id: int = Field(..., description="Topic ID for the concept")
    part_of_speech: str = Field(..., description="Part of speech (e.g., 'verb', 'noun')")
    core_meaning_en: str = Field(..., description="Core meaning in English")
    excluded_senses: Optional[List[str]] = Field(default=[], description="List of excluded senses")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate cards for")


class LLMConceptData(BaseModel):
    """Pydantic model for concept-level data from LLM."""
    description: str
    frequency_bucket: str = Field(..., pattern="^(very_common|common|medium|rare)$")


class LLMCardData(BaseModel):
    """Pydantic model for card data from LLM."""
    language_code: str
    term: str
    ipa: Optional[str] = None
    description: Optional[str] = None
    gender: Optional[str] = None
    article: Optional[str] = None
    plural_form: Optional[str] = None
    verb_type: Optional[str] = None
    auxiliary_verb: Optional[str] = None
    register: Optional[str] = Field(None, pattern="^(neutral|formal|informal|slang)$")


class LLMResponse(BaseModel):
    """Pydantic model for validating LLM output."""
    concept: LLMConceptData
    cards: List[LLMCardData]


class CreateConceptResponse(BaseModel):
    """Response schema for concept creation."""
    concept: ConceptResponse
    cards: List[CardResponse]

