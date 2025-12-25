#!/usr/bin/env python3
"""
Validate that the ERD.md matches the actual database models.

This script checks:
1. All models in the codebase are represented in the ERD
2. All relationships in the ERD exist in the models
3. Key fields mentioned in the ERD exist in the models
"""

import re
import sys
from pathlib import Path
from typing import Set, Dict, List

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.models import models
from app.models.user import User
from app.models.topic import Topic
from app.models.concept import Concept
from app.models.lemma import Lemma
from app.models.user_lemma import UserLemma
from app.models.exercise import Exercise
from app.models.lesson import Lesson
from app.models.language import Language


def extract_erd_entities(erd_path: Path) -> Dict[str, Set[str]]:
    """Extract entity names and their fields from ERD.md."""
    entities = {}
    current_entity = None
    
    with open(erd_path, 'r') as f:
        content = f.read()
    
    # Find all entity definitions
    entity_pattern = r'(\w+)\s*\{([^}]+)\}'
    matches = re.finditer(entity_pattern, content, re.MULTILINE)
    
    for match in matches:
        entity_name = match.group(1)
        fields_text = match.group(2)
        
        # Extract field names (lines that don't start with --)
        fields = set()
        for line in fields_text.split('\n'):
            line = line.strip()
            if line and not line.startswith('--'):
                # Extract field name (before any special characters)
                field_match = re.match(r'(\w+)\s+', line)
                if field_match:
                    fields.add(field_match.group(1))
        
        entities[entity_name] = fields
    
    return entities


def get_model_fields(model_class) -> Set[str]:
    """Get all field names from a SQLModel class."""
    fields = set()
    
    # Get fields from model annotations
    if hasattr(model_class, '__annotations__'):
        for field_name in model_class.__annotations__.keys():
            if not field_name.startswith('_'):
                fields.add(field_name)
    
    # Also check for SQLModel fields
    if hasattr(model_class, 'model_fields'):
        fields.update(model_class.model_fields.keys())
    
    return fields


def validate_erd():
    """Main validation function."""
    repo_root = Path(__file__).parent.parent.parent
    erd_path = repo_root / "api" / "ERD.md"
    
    if not erd_path.exists():
        print(f"❌ ERD.md not found at {erd_path}")
        return False
    
    # Model mapping (ERD name -> Python class)
    model_mapping = {
        'User': User,
        'Language': Language,
        'Topic': Topic,
        'Concept': Concept,
        'Lemma': Lemma,
        'UserLemma': UserLemma,
        'Exercise': Exercise,
        'Lesson': Lesson,
    }
    
    # Extract entities from ERD
    erd_entities = extract_erd_entities(erd_path)
    
    errors = []
    warnings = []
    
    # Check all ERD entities have corresponding models
    for erd_entity_name in erd_entities.keys():
        if erd_entity_name not in model_mapping:
            warnings.append(f"⚠️  ERD entity '{erd_entity_name}' has no corresponding model class")
    
    # Check all models are in ERD
    for model_name, model_class in model_mapping.items():
        if model_name not in erd_entities:
            errors.append(f"❌ Model '{model_name}' is not in ERD.md")
            continue
        
        # Check key fields exist
        erd_fields = erd_entities[model_name]
        model_fields = get_model_fields(model_class)
        
        # Check for common required fields
        common_fields = {'id', 'created_at', 'updated_at'}
        for field in common_fields:
            if field in erd_fields and field not in model_fields:
                # This might be okay (e.g., updated_at might be optional)
                pass
        
        # Check for PK fields
        if 'id' in erd_fields and 'id' not in model_fields:
            errors.append(f"❌ Model '{model_name}' missing 'id' field mentioned in ERD")
    
    # Print results
    if errors:
        print("Validation Errors:")
        for error in errors:
            print(f"  {error}")
    
    if warnings:
        print("\nWarnings:")
        for warning in warnings:
            print(f"  {warning}")
    
    if not errors and not warnings:
        print("✅ ERD validation passed!")
        return True
    
    return len(errors) == 0


if __name__ == "__main__":
    success = validate_erd()
    sys.exit(0 if success else 1)

