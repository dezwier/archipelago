"""
Lemma model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
from sqlalchemy import Column, String as SAString


class Lemma(SQLModel, table=True):
    """Lemma table - language-specific representation of a concept."""
    __tablename__ = "lemma"
    # Note: Unique constraint is enforced via case-insensitive functional index
    # uq_lemma_concept_language_term_ci on (concept_id, language_code, LOWER(TRIM(term)))
    # This prevents duplicates like "Abandon" and "abandon"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    concept_id: int = Field(foreign_key="concept.id")
    language_code: str = Field(foreign_key="languages.code", max_length=2)
    term: str  # The word in the target language (former translation)
    ipa: Optional[str] = None  # Pronunciation in IPA symbols
    description: Optional[str] = None  # Description in the target language
    gender: Optional[str] = None  # For French/Spanish/German
    article: Optional[str] = None  # Article (e.g., 'le', 'la', 'les' in French)
    plural_form: Optional[str] = None  # Plural form of the term
    verb_type: Optional[str] = None  # Verb type (e.g., 'regular', 'irregular')
    auxiliary_verb: Optional[str] = None  # Auxiliary verb (e.g., 'avoir', 'être' in French)
    formality_register: Optional[str] = Field(default=None, sa_column=Column("register", SAString))  # Register (e.g., 'formal', 'informal', 'slang')
    confidence_score: Optional[float] = None  # Confidence score for the lemma
    status: Optional[str] = None  # Status of the lemma
    source: Optional[str] = None  # Source of the lemma data
    audio_url: Optional[str] = None  # Audio URL for pronunciation
    notes: Optional[str] = None  # Additional notes for the lemma
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    
    # Relationships
    concept: "Concept" = Relationship(back_populates="lemmas")
    language: "Language" = Relationship(back_populates="lemmas")
    cards: List["Card"] = Relationship(back_populates="lemma")

