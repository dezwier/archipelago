#!/usr/bin/env python3
"""Test script to verify Google Cloud Translation API key works."""

import os
import sys
from pathlib import Path

# Change to api directory to ensure .env is found
api_dir = Path(__file__).parent
os.chdir(api_dir)

# Set a dummy DATABASE_URL to avoid config error (we don't need DB for this test)
os.environ.setdefault("DATABASE_URL", "postgresql://dummy:dummy@localhost/dummy")

# Add the api directory to the path so we can import app modules
sys.path.insert(0, str(api_dir))

from app.services.translation_service import translation_service
from app.core.config import settings

def test_translation():
    """Test the translation service."""
    print("=" * 60)
    print("Testing Google Cloud Translation API")
    print("=" * 60)
    
    # Check if API key is configured
    if not settings.google_translate_api_key:
        print("❌ ERROR: GOOGLE_TRANSLATE_API_KEY not found in environment")
        print("\nMake sure you have:")
        print("1. Created a .env file in the api/ directory")
        print("2. Added: GOOGLE_TRANSLATE_API_KEY=your_key_here")
        return False
    
    print(f"✓ API Key found: {settings.google_translate_api_key[:10]}...")
    print()
    
    # Test translation
    test_cases = [
        ("hello", "en", "fr", "bonjour"),
        ("cat", "en", "es", "gato"),
        ("house", "en", "de", "Haus"),
    ]
    
    print("Testing translations:")
    print("-" * 60)
    
    all_passed = True
    for text, source, target, expected_start in test_cases:
        try:
            print(f"Translating '{text}' ({source} → {target})...", end=" ")
            result = translation_service.translate_text(
                text=text,
                target_language=target,
                source_language=source
            )
            print(f"✓ Got: '{result}'")
            
            # Check if result starts with expected (case-insensitive)
            if result.lower().startswith(expected_start.lower()):
                print(f"  ✓ Translation looks correct!")
            else:
                print(f"  ⚠ Expected something starting with '{expected_start}', got '{result}'")
            
        except Exception as e:
            print(f"❌ FAILED: {str(e)}")
            all_passed = False
    
    print("-" * 60)
    
    if all_passed:
        print("\n✅ All tests passed! Translation API is working correctly.")
        return True
    else:
        print("\n❌ Some tests failed. Check the errors above.")
        return False

if __name__ == "__main__":
    success = test_translation()
    sys.exit(0 if success else 1)

