from pydantic import BaseModel, Field, computed_field, field_validator
from typing import Optional, List
from datetime import datetime
from app.models.models import CEFRLevel


def normalize_part_of_speech(v: Optional[str]) -> Optional[str]:
    """
    Normalize part_of_speech value to proper case.
    Handles both lowercase and capitalized inputs.
    
    Args:
        v: Part of speech value (can be None, lowercase, or capitalized)
        
    Returns:
        Normalized part of speech value in proper case, or None
    """
    if v is None:
        return None
    
    v_normalized = v.strip()
    if not v_normalized:
        return None
    
    # Map of lowercase to proper case
    pos_map = {
        'noun': 'Noun',
        'verb': 'Verb',
        'adjective': 'Adjective',
        'adverb': 'Adverb',
        'pronoun': 'Pronoun',
        'preposition': 'Preposition',
        'conjunction': 'Conjunction',
        'determiner / article': 'Determiner / Article',
        'determiner': 'Determiner / Article',
        'article': 'Determiner / Article',
        'interjection': 'Interjection',
        'saying': 'Saying',
        'sentence': 'Sentence'
    }
    
    # Try to normalize
    v_lower = v_normalized.lower()
    if v_lower in pos_map:
        return pos_map[v_lower]
    
    # If already in proper format, check if valid
    valid_values = ['Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 'Conjunction', 'Determiner / Article', 'Interjection', 'Saying', 'Sentence']
    if v_normalized in valid_values:
        return v_normalized
    
    # If not found, raise error
    raise ValueError(f"part_of_speech must be one of: {', '.join(valid_values)}. Got: {v}")


class CardResponse(BaseModel):
    """Card response schema."""
    id: int
    concept_id: int
    language_code: str
    translation: str
    description: Optional[str] = None
    ipa: Optional[str] = None
    audio_path: Optional[str] = None
    gender: Optional[str] = None
    article: Optional[str] = None
    plural_form: Optional[str] = None
    verb_type: Optional[str] = None
    auxiliary_verb: Optional[str] = None
    formality_register: Optional[str] = None
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
    description: Optional[str] = None
    user_id: int
    created_at: str

    class Config:
        from_attributes = True


class PairedVocabularyItem(BaseModel):
    """Paired vocabulary item - groups cards by concept."""
    concept_id: int
    cards: List[CardResponse] = Field(default=[], description="All cards for this concept")
    source_card: Optional[CardResponse] = None
    target_card: Optional[CardResponse] = None
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
    concepts_with_all_visible_languages: Optional[int] = Field(None, description="Count of concepts that have cards for all visible languages")
    total_concepts_with_term: Optional[int] = Field(None, description="Total number of concepts with at least a term (not affected by search)")


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
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")
    part_of_speech: Optional[str] = Field(None, description="Part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence. If not provided, will be inferred from the term.")
    core_meaning_en: Optional[str] = Field(None, description="Core meaning in English")
    excluded_senses: Optional[List[str]] = Field(default=[], description="List of excluded senses")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate cards for")
    
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


class LLMCardData(BaseModel):
    """Pydantic model for card data from LLM."""
    language_code: str
    term: str
    ipa: Optional[str] = None
    description: str
    gender: Optional[str] = None
    article: Optional[str] = None
    plural_form: Optional[str] = None
    verb_type: Optional[str] = None
    auxiliary_verb: Optional[str] = None
    formality_register: Optional[str] = Field(default=None, alias="register")
    
    @field_validator('term')
    @classmethod
    def validate_term(cls, v):
        """Validate term field is not empty."""
        if not v or not v.strip():
            raise ValueError("term cannot be missing or empty")
        return v.strip()
    
    @field_validator('description')
    @classmethod
    def validate_description(cls, v):
        """Validate description field is not empty."""
        if not v or not v.strip():
            raise ValueError("description cannot be missing or empty")
        return v.strip()
    
    @field_validator('gender', mode='before')
    @classmethod
    def validate_gender(cls, v):
        """Validate gender field if provided."""
        if v is not None and v not in ['masculine', 'feminine', 'neuter']:
            raise ValueError(f"gender must be one of: masculine, feminine, neuter, or null. Got: {v}")
        return v
    
    @field_validator('formality_register', mode='before')
    @classmethod
    def validate_formality_register(cls, v):
        """Validate formality_register field if provided."""
        if v is not None and v not in ['neutral', 'formal', 'informal', 'slang']:
            raise ValueError(f"formality_register must be one of: neutral, formal, informal, slang, or null. Got: {v}")
        return v
    
    class Config:
        populate_by_name = True  # Allow both 'register' and 'formality_register' in JSON


class LLMResponse(BaseModel):
    """Pydantic model for validating LLM output."""
    concept: LLMConceptData
    cards: List[LLMCardData]


class CreateConceptResponse(BaseModel):
    """Response schema for concept creation."""
    concept: ConceptResponse
    cards: List[CardResponse]


class PreviewConceptResponse(BaseModel):
    """Response schema for concept preview (before saving)."""
    concept: LLMConceptData
    cards: List[LLMCardData]
    message: str = "Preview generated successfully"


class ConfirmConceptRequest(BaseModel):
    """Request schema for confirming a previewed concept."""
    term: str = Field(..., min_length=1, description="The term")
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")
    part_of_speech: Optional[str] = Field(None, description="Part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence. May be inferred if not provided.")
    concept: LLMConceptData = Field(..., description="Concept data from preview")
    cards: List[LLMCardData] = Field(..., description="Card data from preview")
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field if provided."""
        return normalize_part_of_speech(v)


class CreateConceptOnlyRequest(BaseModel):
    """Request schema for creating only a concept (without cards)."""
    term: str = Field(..., min_length=1, description="The term")
    description: Optional[str] = Field(None, description="Description of the concept")
    topic_id: Optional[int] = Field(None, description="Topic ID for the concept")
    user_id: Optional[int] = Field(None, description="User ID who created the concept")


class ConceptWithMissingLanguages(BaseModel):
    """Schema for a concept with missing languages."""
    concept: ConceptResponse
    missing_languages: List[str] = Field(..., description="List of language codes that are missing cards for this concept")


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
    search: Optional[str] = Field(None, description="Optional search query to filter by concept.term and card.term")


class GenerateCardsForConceptsRequest(BaseModel):
    """Request schema for generating cards for concepts."""
    concept_ids: List[int] = Field(..., min_items=1, description="List of concept IDs to generate cards for")
    languages: List[str] = Field(..., min_items=1, description="List of language codes to generate cards for")
    user_id: Optional[int] = Field(None, description="Optional user ID for prioritizing user's concepts in sorting")


class GenerateCardsForConceptsResponse(BaseModel):
    """Response schema for generating cards for concepts."""
    concepts_processed: int = Field(..., description="Number of concepts processed")
    cards_created: int = Field(..., description="Total number of cards created")
    errors: List[str] = Field(default=[], description="List of error messages for concepts that failed")
    total_concepts: int = Field(..., description="Total number of concepts to process")
    session_cost_usd: float = Field(default=0.0, description="Total cost in USD for this generation session")
    total_tokens: int = Field(default=0, description="Total tokens used in this session")


class ConceptCountResponse(BaseModel):
    """Response schema for concept count endpoints."""
    count: int = Field(..., description="Total count of concepts")


class GenerateLemmaRequest(BaseModel):
    """Request schema for generating a lemma (translation)."""
    term: str = Field(..., min_length=1, description="The term to translate (can be a single word or phrase)")
    target_language: str = Field(..., min_length=1, description="Language code to translate to")
    description: Optional[str] = Field(None, description="Optional description/context for the term")
    part_of_speech: Optional[str] = Field(None, description="Optional part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence. If not provided, will be inferred.")
    concept_id: Optional[int] = Field(None, description="Optional concept ID. If provided, the generated lemma will be saved as a card for this concept.")
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field if provided."""
        return normalize_part_of_speech(v)


class GenerateLemmaResponse(BaseModel):
    """Response schema for lemma generation."""
    term: str = Field(..., description="The translated term in the target language")
    ipa: Optional[str] = Field(None, description="IPA pronunciation")
    description: str = Field(..., description="Description in the target language")
    gender: Optional[str] = Field(None, description="Gender (masculine, feminine, neuter, or null)")
    article: Optional[str] = Field(None, description="Article (for languages with articles)")
    plural_form: Optional[str] = Field(None, description="Plural form (for nouns)")
    verb_type: Optional[str] = Field(None, description="Verb type (for verbs)")
    auxiliary_verb: Optional[str] = Field(None, description="Auxiliary verb (for verbs in languages like French)")
    register: Optional[str] = Field(None, description="Register (neutral, formal, informal, slang, or null)")
    token_usage: Optional[dict] = Field(None, description="Token usage information from LLM call")


class GenerateLemmasBatchRequest(BaseModel):
    """Request schema for generating multiple lemmas for the same term in different languages."""
    term: str = Field(..., min_length=1, description="The term to translate (can be a single word or phrase)")
    target_languages: List[str] = Field(..., min_items=1, description="List of language codes to translate to")
    description: Optional[str] = Field(None, description="Optional description/context for the term")
    part_of_speech: Optional[str] = Field(None, description="Optional part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence. If not provided, will be inferred.")
    concept_id: Optional[int] = Field(None, description="Optional concept ID. If provided, the generated lemmas will be saved as cards for this concept.")
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field if provided."""
        return normalize_part_of_speech(v)


class GenerateLemmasBatchResponse(BaseModel):
    """Response schema for batch lemma generation."""
    lemmas: List[GenerateLemmaResponse] = Field(..., description="List of generated lemmas, one per target language")
    total_token_usage: Optional[dict] = Field(None, description="Total token usage across all generations")

