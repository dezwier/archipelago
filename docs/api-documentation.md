# API Documentation

## Overview

The Archipelago API is a RESTful API built with FastAPI. It provides endpoints for managing language learning data including concepts, lemmas, exercises, and user progress.

## Base URL

- **Production**: `https://archipelago-production.up.railway.app`
- **Development**: `http://localhost:8000`

## API Versioning

All endpoints are prefixed with `/api/v1/`.

## Interactive Documentation

FastAPI automatically generates interactive API documentation:

- **Swagger UI**: `http://localhost:8000/docs` (when running locally)
- **ReDoc**: `http://localhost:8000/redoc` (when running locally)

These docs are always up-to-date with the code and include:
- All available endpoints
- Request/response schemas
- Try-it-out functionality
- Authentication requirements

## Authentication

Most endpoints require authentication via JWT tokens obtained from `/api/v1/auth/login`.

### Authentication Header

```
Authorization: Bearer <token>
```

## Endpoints Overview

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration

### Languages
- `GET /api/v1/languages` - Get all supported languages

### Topics
- `GET /api/v1/topics` - Get user's topics
- `POST /api/v1/topics` - Create a topic
- `PATCH /api/v1/topics/{id}` - Update a topic
- `DELETE /api/v1/topics/{id}` - Delete a topic

### Concepts
- `GET /api/v1/concepts` - Get concepts (with filters)
- `POST /api/v1/concepts` - Create a concept
- `GET /api/v1/concepts/{id}` - Get a specific concept
- `PATCH /api/v1/concepts/{id}` - Update a concept
- `DELETE /api/v1/concepts/{id}` - Delete a concept

### Dictionary
- `GET /api/v1/dictionary` - Get dictionary view (concepts with lemmas)

### Lemmas
- `GET /api/v1/lemmas` - Get lemmas (with filters)
- `POST /api/v1/lemmas` - Create a lemma
- `GET /api/v1/lemmas/{id}` - Get a specific lemma
- `PATCH /api/v1/lemmas/{id}` - Update a lemma
- `DELETE /api/v1/lemmas/{id}` - Delete a lemma

### Lemma Generation
- `POST /api/v1/lemma-generation/generate` - Generate lemmas for a concept

### Concept Images
- `POST /api/v1/concept-image/generate` - Generate image for a concept

### Lemma Audio
- `POST /api/v1/lemma-audio/generate` - Generate audio for a lemma

### Lessons
- `GET /api/v1/lessons` - Get user's lessons
- `POST /api/v1/lessons` - Create a lesson
- `GET /api/v1/lessons/{id}` - Get a specific lesson
- `PATCH /api/v1/lessons/{id}` - Update a lesson

### Exercises
- `GET /api/v1/exercises` - Get exercises (with filters)
- `POST /api/v1/exercises` - Create an exercise

### User Statistics
- `GET /api/v1/user-lemma-stats/summary` - Get summary statistics
- `GET /api/v1/user-lemma-stats/leitner-distribution` - Get Leitner distribution
- `GET /api/v1/user-lemma-stats/practice-daily` - Get daily practice statistics

### Flashcard Export
- `GET /api/v1/flashcard-export/export` - Export flashcards

## Common Query Parameters

Many GET endpoints support filtering via query parameters:

- `topic_ids`: Comma-separated topic IDs
- `language_codes`: Comma-separated language codes
- `levels`: Comma-separated CEFR levels (A1, A2, B1, B2, C1, C2)
- `part_of_speech`: Part of speech filter
- `include_phrases`: Boolean (true/false)
- `include_lemmas`: Boolean (true/false)
- `has_images`: Boolean (true/false)
- `has_audio`: Boolean (true/false)
- `is_complete`: Boolean (true/false)

## Response Formats

### Success Response
```json
{
  "id": 1,
  "field": "value",
  ...
}
```

### Error Response
```json
{
  "detail": "Error message",
  "type": "ErrorType"
}
```

### List Response
```json
[
  {
    "id": 1,
    "field": "value"
  },
  {
    "id": 2,
    "field": "value"
  }
]
```

## Status Codes

- `200 OK` - Successful request
- `201 Created` - Resource created
- `400 Bad Request` - Invalid request
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource conflict (e.g., duplicate)
- `422 Unprocessable Entity` - Validation error
- `500 Internal Server Error` - Server error

## Rate Limiting

(Currently not implemented, but may be added in the future)

## CORS

CORS is configured to allow requests from the Flutter app origins. See `api/app/main.py` for configuration.

## Schema Definitions

Request and response schemas are defined using Pydantic models in `api/app/schemas/`. These ensure:
- Type validation
- Automatic serialization/deserialization
- API documentation generation

## Best Practices

1. **Always check the interactive docs** (`/docs`) for the most up-to-date endpoint information
2. **Use proper HTTP methods**: GET for reads, POST for creates, PATCH for updates, DELETE for deletes
3. **Handle errors gracefully**: Check status codes and parse error responses
4. **Include authentication tokens** for protected endpoints
5. **Use query parameters** for filtering rather than request bodies in GET requests
6. **Validate input** on the frontend before sending requests

## Example Requests

### Login
```bash
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "pass"}'
```

### Get Dictionary
```bash
curl -X GET "http://localhost:8000/api/v1/dictionary?language_codes=fr,es&topic_ids=1,2" \
  -H "Authorization: Bearer <token>"
```

### Create Concept
```bash
curl -X POST "http://localhost:8000/api/v1/concepts" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "term": "hello",
    "description": "A greeting",
    "topic_id": 1
  }'
```

## Keeping Documentation Updated

The FastAPI interactive documentation (`/docs` and `/redoc`) is automatically generated from the code and is always up-to-date. This markdown file provides an overview, but for detailed, always-current documentation, use the interactive docs.

