"""
Language model.
"""
from sqlmodel import SQLModel, Field, Relationship
from typing import List


class Language(SQLModel, table=True):
    """Language table - stores supported languages."""
    __tablename__ = "languages"
    
    code: str = Field(primary_key=True, max_length=2)  # e.g., 'en', 'fr', 'es', 'jp'
    name: str  # English, French, Spanish, etc.
    
    # Relationships
    lemmas: List["Lemma"] = Relationship(back_populates="language")

