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

    class Config:
        from_attributes = True


class VocabularyResponse(BaseModel):
    """Response schema for vocabulary endpoint."""
    items: List[PairedVocabularyItem]


class UpdateCardRequest(BaseModel):
    """Request schema for updating a card."""
    translation: Optional[str] = Field(None, min_length=1, description="Updated translation text")
    description: Optional[str] = Field(None, description="Updated description text")

