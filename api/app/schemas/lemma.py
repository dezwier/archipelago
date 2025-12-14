from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from app.schemas.utils import normalize_part_of_speech


class LemmaResponse(BaseModel):
    """Lemma response schema."""
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


class UpdateLemmaRequest(BaseModel):
    """Request schema for updating a lemma."""
    translation: Optional[str] = Field(None, min_length=1, description="Updated translation text")
    description: Optional[str] = Field(None, description="Updated description text")


class LLMLemmaData(BaseModel):
    """Pydantic model for lemma data from LLM."""
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


class GenerateLemmaRequest(BaseModel):
    """Request schema for generating a lemma (translation)."""
    term: str = Field(..., min_length=1, description="The term to translate (can be a single word or phrase)")
    target_language: str = Field(..., min_length=1, description="Language code to translate to")
    description: Optional[str] = Field(None, description="Optional description/context for the term")
    part_of_speech: Optional[str] = Field(None, description="Optional part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection. If not provided, will be inferred.")
    concept_id: Optional[int] = Field(None, description="Optional concept ID. If provided, the generated lemma will be saved as a lemma for this concept.")
    
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
    part_of_speech: Optional[str] = Field(None, description="Optional part of speech. Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection. If not provided, will be inferred.")
    concept_id: Optional[int] = Field(None, description="Optional concept ID. If provided, the generated lemmas will be saved as lemmas for this concept.")
    
    @field_validator('part_of_speech')
    @classmethod
    def validate_part_of_speech(cls, v):
        """Validate and normalize part_of_speech field if provided."""
        return normalize_part_of_speech(v)


class GenerateLemmasBatchResponse(BaseModel):
    """Response schema for batch lemma generation."""
    lemmas: List[GenerateLemmaResponse] = Field(..., description="List of generated lemmas, one per target language")
    total_token_usage: Optional[dict] = Field(None, description="Total token usage across all generations")

