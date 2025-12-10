from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
from enum import Enum
import hashlib
from sqlalchemy import Column, String as SAString


class UserCardStatus(str, Enum):
    """Status enum for UserCard."""
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    MASTERED = "mastered"


class CEFRLevel(str, Enum):
    """CEFR language proficiency levels."""
    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"
    C2 = "C2"


class Topic(SQLModel, table=True):
    """Topic table for grouping concepts."""
    __tablename__ = "topic"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    concepts: List["Concept"] = Relationship(back_populates="topic")


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
    concept: "Concept" = Relationship(back_populates="images")


class Concept(SQLModel, table=True):
    """Concept table - represents a concept that can have multiple language cards."""
    __tablename__ = "concept"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    topic_id: Optional[int] = Field(default=None, foreign_key="topic.id")
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")  # User who created the concept (null for script-created concepts)
    term: str  # Former internal_name - English translation for the concept (mandatory)
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    frequency_bucket: Optional[str] = None
    level: Optional[CEFRLevel] = None  # CEFR language proficiency level (A1-C2)
    status: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    
    # Relationships
    topic: Optional[Topic] = Relationship(back_populates="concepts")
    cards: List["Card"] = Relationship(back_populates="concept")
    images: List["Image"] = Relationship(back_populates="concept")


class Language(SQLModel, table=True):
    """Language table - stores supported languages."""
    __tablename__ = "languages"
    
    code: str = Field(primary_key=True, max_length=2)  # e.g., 'en', 'fr', 'es', 'jp'
    name: str  # English, French, Spanish, etc.
    
    # Relationships
    cards: List["Card"] = Relationship(back_populates="language")


class Card(SQLModel, table=True):
    """Card table - language-specific representation of a concept."""
    __tablename__ = "card"
    # Note: Unique constraint is enforced via case-insensitive functional index
    # uq_card_concept_language_term_ci on (concept_id, language_code, LOWER(TRIM(term)))
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
    confidence_score: Optional[float] = None  # Confidence score for the card
    status: Optional[str] = None  # Status of the card
    source: Optional[str] = None  # Source of the card data
    audio_url: Optional[str] = None  # Audio URL for pronunciation
    notes: Optional[str] = None  # Additional notes for the card
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    
    # Relationships
    concept: Concept = Relationship(back_populates="cards")
    language: Language = Relationship(back_populates="cards")
    user_cards: List["UserCard"] = Relationship(back_populates="card")


class User(SQLModel, table=True):
    """User table - stores user information."""
    __tablename__ = "users"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)  # Unique username
    email: str = Field(unique=True, index=True)  # Email address
    password: str  # Hashed password
    lang_native: str  # Native language code
    lang_learning: str  # Learning language code
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    user_cards: List["UserCard"] = Relationship(back_populates="user")
    practices: List["UserPractice"] = Relationship(back_populates="user")
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Simple password hashing using SHA256."""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password: str) -> bool:
        """Verify a password against the stored hash."""
        return self.password == self.hash_password(password)


class UserCard(SQLModel, table=True):
    """UserCard table - tracks user's progress with specific cards."""
    __tablename__ = "user_cards"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    card_id: int = Field(foreign_key="card.id")
    image_path: Optional[str] = None
    created_time: datetime = Field(default_factory=datetime.utcnow)
    last_success_time: Optional[datetime] = None
    status: UserCardStatus = Field(default=UserCardStatus.NEW)
    next_review_at: Optional[datetime] = None  # Calculated by SRS
    
    # Relationships
    user: User = Relationship(back_populates="user_cards")
    card: Card = Relationship(back_populates="user_cards")


class UserPractice(SQLModel, table=True):
    """UserPractice table - tracks practice sessions."""
    __tablename__ = "user_practices"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    created_time: datetime = Field(default_factory=datetime.utcnow)
    success: bool
    feedback: Optional[int] = None  # User feedback score
    
    # Relationships
    user: User = Relationship(back_populates="practices")

