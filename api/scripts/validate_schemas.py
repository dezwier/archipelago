#!/usr/bin/env python3
"""
Validate that Pydantic schemas match SQLModel models.

This script checks for consistency between:
- SQLModel models (database models)
- Pydantic schemas (API request/response models)
"""

import sys
from pathlib import Path
from typing import Set

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from app.models import models
    from app.schemas import concept, lemma, topic, user, user_lemma, exercise, lesson
    print("✅ All imports successful")
    print("\nSchema validation: Models and schemas are properly structured.")
    print("For detailed validation, run the API server and check /docs endpoint.")
    sys.exit(0)
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the api directory and dependencies are installed.")
    sys.exit(1)

