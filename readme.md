# Archipelago

A language learning application with spaced repetition (Leitner system) for vocabulary acquisition.

## Project Structure

- **Frontend**: Flutter app (`app/`)
- **Backend**: FastAPI Python API (`api/`)
- **Database**: PostgreSQL

## Documentation

Comprehensive documentation is available in the [`docs/`](./docs/) directory:

- **[Documentation Index](./docs/README.md)** - Overview of all documentation
- **[Data Model](./docs/data-model.md)** - Database schema and entity relationships
- **[API Flows](./docs/api-flows.md)** - Frontend-to-backend interaction flows
- **[Architecture](./docs/architecture.md)** - System architecture and design
- **[API Documentation](./docs/api-documentation.md)** - API endpoint reference

## Quick Start

### Backend

```bash
cd api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
# Set up database and run migrations
uvicorn app.main:app --reload
```

API docs available at: http://localhost:8000/docs

### Frontend

```bash
cd app
flutter pub get
flutter run
```

## Database ERD

See [`api/ERD.md`](./api/ERD.md) for the Entity Relationship Diagram (Mermaid format).

## Keeping Documentation Updated

See [`docs/README.md`](./docs/README.md) for information on tools and processes to keep documentation up-to-date.

