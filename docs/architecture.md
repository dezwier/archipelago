# Architecture Documentation

## System Overview

Archipelago is a language learning application with a Flutter mobile frontend and a FastAPI backend.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Features   │  │   Services   │  │   Providers  │      │
│  │              │  │              │  │              │      │
│  │ - Learn      │  │ - Auth       │  │ - Auth       │      │
│  │ - Dictionary │  │ - Dictionary │  │ - Languages  │      │
│  │ - Create     │  │ - Concepts   │  │ - Topics     │      │
│  │ - Profile    │  │ - Lessons    │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP/REST
                            │ JSON
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   API v1     │  │   Services   │  │   Models     │      │
│  │              │  │              │  │              │      │
│  │ - Endpoints  │  │ - Business   │  │ - SQLModel   │      │
│  │ - Schemas    │  │   Logic      │  │ - Relations  │      │
│  │ - Auth       │  │ - AI/TTS     │  │ - Enums      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ SQLAlchemy
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Tables     │  │   Indexes    │  │ Constraints  │      │
│  │              │  │              │  │              │      │
│  │ - Users      │  │ - Primary    │  │ - Foreign    │      │
│  │ - Concepts   │  │   Keys       │  │   Keys       │      │
│  │ - Lemmas     │  │ - Unique     │  │ - Unique     │      │
│  │ - Exercises  │  │   Indexes    │  │   Constraints│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Frontend Architecture (Flutter)

### Directory Structure

```
app/lib/src/
├── features/           # Feature modules
│   ├── learn/         # Learning/practice feature
│   ├── dictionary/    # Dictionary view feature
│   ├── create/        # Concept creation feature
│   ├── profile/       # User profile feature
│   └── shared/        # Shared domain models
├── common_widgets/    # Reusable UI components
├── constants/         # App constants (API config, etc.)
└── utils/            # Utility functions
```

### Feature Module Structure

Each feature follows a clean architecture pattern:

```
feature_name/
├── data/              # Data layer
│   └── *_service.dart # API service classes
├── domain/            # Domain layer
│   └── *.dart        # Domain models
├── presentation/      # Presentation layer
│   ├── screens/      # Screen widgets
│   ├── widgets/      # Feature-specific widgets
│   └── controllers/  # State management
```

### State Management

- **Providers**: Used for global state (auth, languages, topics)
- **StatefulWidget**: Used for local UI state
- **Controllers**: Used for complex feature state management

### API Communication

- Direct HTTP calls using `http` package
- Services abstract API endpoints
- Centralized API config in `constants/api_config.dart`
- Standardized error handling

## Backend Architecture (FastAPI)

### Directory Structure

```
api/app/
├── api/v1/           # API version 1
│   └── endpoints/    # Route handlers
├── core/             # Core configuration
│   ├── config.py    # Settings
│   ├── database.py  # DB connection
│   └── exceptions.py # Custom exceptions
├── models/           # Database models (SQLModel)
├── schemas/          # Pydantic schemas (request/response)
└── services/         # Business logic layer
```

### API Structure

- **RESTful design**: Standard HTTP methods (GET, POST, PATCH, DELETE)
- **Versioning**: `/api/v1/` prefix
- **Authentication**: JWT tokens
- **Documentation**: Auto-generated Swagger/ReDoc at `/docs`

### Database Layer

- **ORM**: SQLModel (built on SQLAlchemy)
- **Migrations**: Alembic
- **Relationships**: Defined in models with back_populates
- **Constraints**: Enforced at database level

### Service Layer

Business logic is separated into service classes:
- Data validation
- External API integration (AI, TTS)
- Complex queries
- Data transformation

## Data Flow

### Read Flow
1. User interacts with Flutter UI
2. Widget calls service method
3. Service makes HTTP GET request
4. FastAPI endpoint receives request
5. Endpoint calls service layer
6. Service queries database via model
7. Response flows back through layers
8. Flutter updates UI

### Write Flow
1. User submits form in Flutter
2. Widget validates input
3. Service makes HTTP POST/PATCH request
4. FastAPI endpoint validates schema
5. Endpoint calls service layer
6. Service performs business logic
7. Service saves to database via model
8. Response confirms success
9. Flutter updates UI

## External Integrations

### AI Services
- **Image Generation**: DALL-E or similar for concept images
- **Lemma Generation**: LLM for generating translations
- **Description Generation**: LLM for concept descriptions

### Text-to-Speech
- **Audio Generation**: TTS service for lemma pronunciation

## Security

- **Authentication**: JWT tokens
- **Authorization**: User-scoped resources
- **CORS**: Configured for frontend origins
- **Input Validation**: Pydantic schemas
- **SQL Injection**: Prevented by ORM

## Deployment

- **Frontend**: Flutter builds to iOS/Android/Web
- **Backend**: FastAPI on Railway (or similar)
- **Database**: PostgreSQL on Railway
- **Assets**: Static file serving for images/fonts

## Development Workflow

1. **Database Changes**: Create Alembic migration
2. **Model Changes**: Update SQLModel classes
3. **Schema Changes**: Update Pydantic schemas
4. **API Changes**: Update endpoint handlers
5. **Frontend Changes**: Update services and UI
6. **Testing**: Test end-to-end flow

## Technology Stack

### Frontend
- **Framework**: Flutter
- **Language**: Dart
- **HTTP Client**: `http` package
- **State Management**: Provider pattern

### Backend
- **Framework**: FastAPI
- **Language**: Python 3.x
- **ORM**: SQLModel
- **Migrations**: Alembic
- **Validation**: Pydantic

### Database
- **RDBMS**: PostgreSQL
- **Connection**: SQLAlchemy

### DevOps
- **Containerization**: Docker
- **Deployment**: Railway
- **CI/CD**: (To be configured)

