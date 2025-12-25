# Data Model Documentation

## Overview

Archipelago uses a relational database model with the following core entities:
- **User**: Application users
- **Language**: Supported languages
- **Topic**: User-created topics for organizing concepts
- **Concept**: Core concepts (words/phrases) that can have multiple language representations
- **Lemma**: Language-specific representation of a concept
- **UserLemma**: User's progress tracking for lemmas (Leitner system)
- **Exercise**: Practice sessions tracking
- **Lesson**: Learning sessions containing multiple exercises

## Entity Relationship Diagram

See [ERD.md](../api/ERD.md) for the visual diagram.

## Core Entities

### User
- **Purpose**: Represents application users
- **Key Fields**:
  - `id`: Primary key
  - `username`: Unique username
  - `email`: Unique email address
  - `lang_native`: User's native language code
  - `lang_learning`: Language the user is learning
- **Relationships**:
  - Has many Topics (creates)
  - Has many Concepts (creates)
  - Has many UserLemmas (tracks progress)
  - Has many Lessons

### Concept
- **Purpose**: Core concept that can be expressed in multiple languages
- **Key Fields**:
  - `id`: Primary key
  - `term`: English term (mandatory)
  - `description`: Concept description
  - `part_of_speech`: Grammatical category
  - `level`: CEFR proficiency level (A1-C2)
  - `is_phrase`: Boolean indicating if it's a phrase (user-created) or word (script-created)
  - `image_url`: URL to concept image
- **Relationships**:
  - Belongs to Topic (optional)
  - Belongs to User (optional, for user-created concepts)
  - Has many Lemmas (one per language)

### Lemma
- **Purpose**: Language-specific representation of a concept
- **Key Fields**:
  - `id`: Primary key
  - `concept_id`: Foreign key to Concept
  - `language_code`: Language code (FK to Language)
  - `term`: The word/phrase in the target language
  - `ipa`: International Phonetic Alphabet pronunciation
  - `audio_url`: URL to audio pronunciation
  - `gender`, `article`, `plural_form`: Language-specific grammatical info
- **Constraints**:
  - Unique constraint: (concept_id, language_code, LOWER(TRIM(term))) - case-insensitive
  - One lemma per language per concept
- **Relationships**:
  - Belongs to Concept
  - Belongs to Language
  - Has many UserLemmas

### UserLemma
- **Purpose**: Tracks user's learning progress for a specific lemma using the Leitner spaced repetition system
- **Key Fields**:
  - `id`: Primary key
  - `user_id`: Foreign key to User
  - `lemma_id`: Foreign key to Lemma
  - `leitner_bin`: Current Leitner box (0-7, where 0 is new/unlearned)
  - `last_review_time`: Last time the user reviewed this lemma
  - `next_review_at`: Scheduled next review time
- **Relationships**:
  - Belongs to User
  - Belongs to Lemma
  - Has many Exercises

### Exercise
- **Purpose**: Records individual practice attempts
- **Key Fields**:
  - `id`: Primary key
  - `user_lemma_id`: Foreign key to UserLemma
  - `lesson_id`: Foreign key to Lesson
  - `exercise_type`: Type of exercise (e.g., "translation", "recognition")
  - `result`: Result of the exercise (e.g., "correct", "incorrect")
  - `start_time`, `end_time`: Timing information
- **Relationships**:
  - Belongs to UserLemma
  - Belongs to Lesson

### Lesson
- **Purpose**: Groups exercises into learning sessions
- **Key Fields**:
  - `id`: Primary key
  - `user_id`: Foreign key to User
  - `learning_language`: Language being practiced (FK to Language)
  - `kind`: Type of lesson (e.g., "new_cards", "review")
  - `start_time`, `end_time`: Session timing
- **Relationships**:
  - Belongs to User
  - Belongs to Language (via learning_language)
  - Has many Exercises

### Topic
- **Purpose**: User-created categories for organizing concepts
- **Key Fields**:
  - `id`: Primary key
  - `user_id`: Foreign key to User
  - `name`: Topic name
  - `description`: Topic description
  - `icon`: Icon identifier
- **Relationships**:
  - Belongs to User
  - Has many Concepts

### Language
- **Purpose**: Supported languages in the system
- **Key Fields**:
  - `code`: Primary key (ISO 639-1 code, e.g., "en", "fr")
  - `name`: Language name
- **Relationships**:
  - Has many Lemmas
  - Has many Lessons (via learning_language)

## Database Migrations

All schema changes are managed through Alembic migrations in `api/alembic/versions/`. The migration history shows the evolution of the schema.

## Model Files

Models are defined in `api/app/models/`:
- `user.py` - User model
- `concept.py` - Concept model
- `lemma.py` - Lemma model
- `user_lemma.py` - UserLemma model
- `exercise.py` - Exercise model
- `lesson.py` - Lesson model
- `topic.py` - Topic model
- `language.py` - Language model
- `enums.py` - Enumeration types (CEFRLevel, etc.)

## Schema Validation

To ensure models match the database schema:
```bash
python api/scripts/validate_schemas.py
```

