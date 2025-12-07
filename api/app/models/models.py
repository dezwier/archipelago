from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
from enum import Enum
import hashlib
from sqlalchemy import UniqueConstraint


class UserCardStatus(str, Enum):
    """Status enum for UserCard."""
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    MASTERED = "mastered"


class Topic(SQLModel, table=True):
    """Topic table for grouping concepts."""
    __tablename__ = "topic"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    concepts: List["Concept"] = Relationship(back_populates="topic")


class Concept(SQLModel, table=True):
    """Concept table - represents a concept that can have multiple language cards."""
    __tablename__ = "concept"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    image_path_1: Optional[str] = None
    image_path_2: Optional[str] = None
    image_path_3: Optional[str] = None
    image_path_4: Optional[str] = None
    topic_id: Optional[int] = Field(default=None, foreign_key="topic.id")
    
    # Relationships
    topic: Optional[Topic] = Relationship(back_populates="concepts")
    cards: List["Card"] = Relationship(back_populates="concept")


class Language(SQLModel, table=True):
    """Language table - stores supported languages."""
    __tablename__ = "languages"
    
    code: str = Field(primary_key=True, max_length=2)  # e.g., 'en', 'fr', 'es', 'jp'
    name: str  # English, French, Spanish, etc.
    
    # Relationships
    cards: List["Card"] = Relationship(back_populates="language")


class Card(SQLModel, table=True):
    """Card table - language-specific representation of a concept."""
    __tablename__ = "cards"
    __table_args__ = (
        UniqueConstraint('concept_id', 'language_code', 'translation', name='uq_card_concept_language_translation'),
    )
    
    id: Optional[int] = Field(default=None, primary_key=True)
    concept_id: int = Field(foreign_key="concept.id")
    language_code: str = Field(foreign_key="languages.code", max_length=2)
    translation: str  # The word in the target language
    description: str  # Description in the target language
    ipa: Optional[str] = None  # Pronunciation in IPA symbols
    audio_path: Optional[str] = None  # Pronunciation file path
    gender: Optional[str] = None  # For French/Spanish/German
    notes: Optional[str] = None  # Context specific to this language
    creation_time: datetime = Field(default_factory=datetime.utcnow)
    
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
    card_id: int = Field(foreign_key="cards.id")
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

