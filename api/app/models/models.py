"""
Models module - re-exports all models for backward compatibility.

This module maintains backward compatibility for imports like:
    from app.models.models import Concept

All models are now in separate files in the models package.
"""
# Re-export everything from the models package
from app.models.enums import CEFRLevel
from app.models.topic import Topic
from app.models.concept import Concept
from app.models.language import Language
from app.models.lemma import Lemma
from app.models.user import User
from app.models.card import Card
from app.models.practice import Practice

__all__ = [
    'CEFRLevel',
    'Topic',
    'Concept',
    'Language',
    'Lemma',
    'User',
    'Card',
    'Practice',
]
