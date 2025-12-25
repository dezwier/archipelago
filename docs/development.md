# Development Guide

## Setup

### Prerequisites

- Python 3.9+
- Flutter SDK
- PostgreSQL
- Node.js (for Mermaid CLI, optional)

### Backend Setup

```bash
cd api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Set up environment variables (create .env file)
# DATABASE_URL=postgresql://user:pass@localhost/archipelago
# SECRET_KEY=your-secret-key
# etc.

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd app
flutter pub get
flutter run
```

## Database Migrations

### Create a Migration

```bash
cd api
alembic revision --autogenerate -m "description"
```

### Apply Migrations

```bash
alembic upgrade head
```

### Rollback Migration

```bash
alembic downgrade -1
```

## Documentation Maintenance

### Validate ERD

```bash
cd api
python scripts/validate_erd.py
```

### Validate Schemas

```bash
cd api
python scripts/validate_schemas.py
```

### Generate ERD Image (requires Node.js)

```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i api/ERD.md -o docs/images/erd.png
```

## Testing

### Backend Tests

```bash
cd api
pytest
```

### Frontend Tests

```bash
cd app
flutter test
```

## Code Style

### Python

- Follow PEP 8
- Use type hints
- Format with `black` (if configured)
- Lint with `pylint` or `flake8` (if configured)

### Dart

- Follow Dart style guide
- Format with `dart format .`
- Analyze with `dart analyze`

## Git Workflow

1. Create feature branch
2. Make changes
3. Run validation scripts
4. Update documentation if needed
5. Commit changes
6. Push and create PR

## Common Tasks

### Adding a New Model

1. Create model in `api/app/models/`
2. Create Alembic migration: `alembic revision --autogenerate -m "add model"`
3. Update `api/ERD.md`
4. Run `validate_erd.py`
5. Create Pydantic schemas in `api/app/schemas/`
6. Update `docs/data-model.md`

### Adding a New API Endpoint

1. Create endpoint in `api/app/api/v1/endpoints/`
2. Add to router in `api/app/api/v1/__init__.py`
3. Create request/response schemas
4. Add business logic in `api/app/services/`
5. Test endpoint at `/docs`
6. Update `docs/api-flows.md` if new flow
7. Update `docs/api-documentation.md` overview

### Adding a New Frontend Feature

1. Create feature directory in `app/lib/src/features/`
2. Follow feature module structure (data/domain/presentation)
3. Create service for API calls
4. Create screens and widgets
5. Update `docs/api-flows.md` if new API interactions

## Troubleshooting

### Database Connection Issues

- Check `DATABASE_URL` in `.env`
- Ensure PostgreSQL is running
- Check database exists

### Migration Issues

- Check Alembic version: `alembic current`
- Review migration files for errors
- Consider manual migration if needed

### API Docs Not Updating

- Restart FastAPI server
- Clear browser cache
- Check endpoint is properly registered

### ERD Validation Fails

- Compare model fields with ERD fields
- Check for typos in field names
- Ensure all models are imported in `models/__init__.py`

