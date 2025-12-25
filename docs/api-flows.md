# API Flow Documentation

This document describes the flow of data and logic from the Flutter frontend to the FastAPI backend.

## Architecture Overview

```
┌─────────────────┐         HTTP/REST          ┌─────────────────┐
│  Flutter App    │ ─────────────────────────> │   FastAPI API   │
│  (Frontend)     │ <───────────────────────── │   (Backend)     │
└─────────────────┘         JSON Response      └─────────────────┘
```

## Common Flow Patterns

### 1. Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant DB as Database

    User->>Flutter: Enter credentials
    Flutter->>API: POST /api/v1/auth/login
    API->>DB: Validate credentials
    DB-->>API: User data
    API-->>Flutter: JWT token + user data
    Flutter->>Flutter: Store token in AuthProvider
    Flutter->>User: Show authenticated UI
```

**Frontend**: `app/lib/src/features/profile/data/auth_service.dart`  
**Backend**: `api/app/api/v1/endpoints/auth.py`

### 2. Dictionary View Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant DB as Database

    User->>Flutter: Open Dictionary screen
    Flutter->>API: GET /api/v1/dictionary
    Note over Flutter,API: Includes filters: topics, languages, etc.
    API->>DB: Query concepts + lemmas
    DB-->>API: Concept data with lemmas
    API-->>Flutter: JSON array of concepts
    Flutter->>Flutter: Parse and display in DictionaryScreen
    Flutter->>User: Show dictionary items
```

**Frontend**: `app/lib/src/features/dictionary/presentation/screens/dictionary_screen.dart`  
**Backend**: `api/app/api/v1/endpoints/dictionary.py`

### 3. Concept Creation Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant DB as Database

    User->>Flutter: Create new concept
    Flutter->>API: POST /api/v1/concepts
    Note over Flutter,API: {term, topic_id, description, ...}
    API->>DB: Insert concept
    DB-->>API: Created concept with ID
    API-->>Flutter: Concept data
    Flutter->>API: POST /api/v1/lemma-generation/generate
    Note over Flutter,API: {concept_id, language_codes}
    API->>API: Generate lemmas (AI/LLM)
    API->>DB: Insert lemmas
    DB-->>API: Created lemmas
    API-->>Flutter: Lemma data
    Flutter->>User: Show created concept with lemmas
```

**Frontend**: `app/lib/src/features/create/presentation/screens/create_screen.dart`  
**Backend**: `api/app/api/v1/endpoints/concepts.py`, `lemma_generation.py`

### 4. Learning Session Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant DB as Database

    User->>Flutter: Start learning session
    Flutter->>API: GET /api/v1/user-lemma-stats/leitner-distribution
    API->>DB: Query user_lemmas with filters
    DB-->>API: UserLemma data
    API-->>Flutter: Leitner distribution stats
    Flutter->>Flutter: Select cards for session
    Flutter->>API: POST /api/v1/lessons
    Note over Flutter,API: Create lesson
    API->>DB: Insert lesson
    DB-->>API: Lesson ID
    API-->>Flutter: Lesson data
    loop For each exercise
        User->>Flutter: Answer exercise
        Flutter->>API: POST /api/v1/exercises
        Note over Flutter,API: {user_lemma_id, lesson_id, result, ...}
        API->>DB: Insert exercise + update UserLemma
        Note over API,DB: Update leitner_bin, next_review_at
        DB-->>API: Success
        API-->>Flutter: Exercise data
    end
    Flutter->>API: PATCH /api/v1/lessons/{id}
    Note over Flutter,API: Update end_time
    API->>DB: Update lesson
    Flutter->>User: Show lesson summary
```

**Frontend**: `app/lib/src/features/learn/presentation/screens/learn_screen.dart`  
**Backend**: `api/app/api/v1/endpoints/lessons.py`, `user_lemma_stats.py`

### 5. Image Generation Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant AI as AI Service
    participant DB as Database

    User->>Flutter: Request image for concept
    Flutter->>API: POST /api/v1/concept-image/generate
    Note over Flutter,API: {concept_id, term, description, ...}
    API->>AI: Generate image (DALL-E/Stable Diffusion)
    AI-->>API: Image URL
    API->>DB: Update concept.image_url
    DB-->>API: Success
    API-->>Flutter: Image URL
    Flutter->>Flutter: Display image with cache-busting
    Flutter->>User: Show generated image
```

**Frontend**: `app/lib/src/common_widgets/concept_drawer/concept_image_widget.dart`  
**Backend**: `api/app/api/v1/endpoints/concept_image.py`

### 6. Audio Generation Flow

```mermaid
sequenceDiagram
    participant User
    participant Flutter as Flutter App
    participant API as FastAPI Backend
    participant TTS as Text-to-Speech Service
    participant DB as Database

    User->>Flutter: Request audio for lemma
    Flutter->>API: POST /api/v1/lemma-audio/generate
    Note over Flutter,API: {lemma_id, language_code, term}
    API->>TTS: Generate audio
    TTS-->>API: Audio file URL
    API->>DB: Update lemma.audio_url
    DB-->>API: Success
    API-->>Flutter: Audio URL
    Flutter->>Flutter: Play audio
    Flutter->>User: Play pronunciation
```

**Frontend**: `app/lib/src/common_widgets/lemma_audio_player.dart`  
**Backend**: `api/app/api/v1/endpoints/lemma_audio.py`

## API Endpoint Mapping

### Frontend Service → Backend Endpoint

| Frontend Service | Backend Endpoint | Purpose |
|----------------|------------------|---------|
| `AuthService` | `/api/v1/auth/login`<br>`/api/v1/auth/register` | Authentication |
| `DictionaryService` | `/api/v1/dictionary` | Get concepts with lemmas |
| `ConceptService` | `/api/v1/concepts` | CRUD operations on concepts |
| `LemmaService` | `/api/v1/lemmas` | CRUD operations on lemmas |
| `LemmaGenerationService` | `/api/v1/lemma-generation/generate` | Generate lemmas for concept |
| `ImageService` | `/api/v1/concept-image/generate` | Generate concept images |
| `LemmaAudioService` | `/api/v1/lemma-audio/generate` | Generate lemma audio |
| `TopicService` | `/api/v1/topics` | CRUD operations on topics |
| `LanguageService` | `/api/v1/languages` | Get supported languages |
| `LessonService` | `/api/v1/lessons` | Create/update lessons |
| `StatisticsService` | `/api/v1/user-lemma-stats/*` | Get user statistics |
| `FlashcardExportService` | `/api/v1/flashcard-export/*` | Export flashcards |

## Request/Response Patterns

### Standard Request Format
```dart
// Flutter
final response = await http.post(
  Uri.parse('${ApiConfig.apiBaseUrl}/endpoint'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token', // If authenticated
  },
  body: jsonEncode(requestBody),
);
```

### Standard Response Handling
```dart
if (response.statusCode == 200) {
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  // Process data
} else {
  final error = jsonDecode(response.body) as Map<String, dynamic>;
  final errorMessage = error['detail'] as String? ?? 'Error occurred';
  // Handle error
}
```

### Error Response Format
```json
{
  "detail": "Error message",
  "type": "ErrorType"
}
```

## Data Flow Layers

1. **Presentation Layer** (Flutter)
   - Screens, widgets, controllers
   - User interaction handling
   - State management

2. **Service Layer** (Flutter)
   - HTTP client calls
   - Request/response parsing
   - Error handling

3. **API Layer** (FastAPI)
   - Endpoint definitions
   - Request validation (Pydantic schemas)
   - Authentication/authorization

4. **Service Layer** (Python)
   - Business logic
   - External service integration (AI, TTS, etc.)
   - Data transformation

5. **Model Layer** (SQLModel)
   - Database models
   - Relationships
   - Data persistence

6. **Database Layer** (PostgreSQL)
   - Data storage
   - Constraints and indexes

## Authentication

Most endpoints require authentication via JWT tokens. The token is obtained from `/api/v1/auth/login` and should be included in the `Authorization` header:

```
Authorization: Bearer <token>
```

## Filtering and Pagination

Many endpoints support filtering via query parameters:
- `topic_ids`: Filter by topic IDs
- `language_codes`: Filter by language codes
- `levels`: Filter by CEFR levels
- `part_of_speech`: Filter by part of speech
- `include_phrases`: Include/exclude phrases
- `include_lemmas`: Include/exclude lemmas

See individual endpoint documentation in the API docs (`/docs`) for specific filter options.

