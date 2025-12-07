from pydantic import BaseModel, Field
from typing import Optional, List


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


class ConceptResponse(BaseModel):
    """Concept response schema."""
    id: int
    image_path_1: Optional[str] = None
    image_path_2: Optional[str] = None
    image_path_3: Optional[str] = None
    image_path_4: Optional[str] = None
    topic_id: Optional[int] = None

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
    image_path_1: Optional[str] = None
    image_path_2: Optional[str] = None
    image_path_3: Optional[str] = None
    image_path_4: Optional[str] = None

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

