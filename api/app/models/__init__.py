"""
Models package - imports all models for backward compatibility.
"""
# Import enums first
from app.models.enums import CEFRLevel

# Import all models
from app.models.topic import Topic
from app.models.concept import Concept
from app.models.language import Language
from app.models.lemma import Lemma
from app.models.user import User
from app.models.user_lemma import UserLemma
from app.models.exercise import Exercise

# For backward compatibility: allow importing from models.models
# This maintains existing imports like "from app.models.models import Concept"
import sys
from types import ModuleType

# Create a models module that mimics the old models.py structure
_models_module = ModuleType('app.models.models')
_models_module.CEFRLevel = CEFRLevel
_models_module.Topic = Topic
_models_module.Concept = Concept
_models_module.Language = Language
_models_module.Lemma = Lemma
_models_module.User = User
_models_module.UserLemma = UserLemma
_models_module.Exercise = Exercise

# Add to sys.modules so imports work
sys.modules['app.models.models'] = _models_module

__all__ = [
    'CEFRLevel',
    'Topic',
    'Concept',
    'Language',
    'Lemma',
    'User',
    'UserLemma',
    'Exercise',
]

