# Archipelago Documentation

This directory contains comprehensive documentation for the Archipelago project, including data models, API flows, and architecture diagrams.

## Documentation Structure

- **[Data Model](./data-model.md)** - Complete database schema documentation
- **[API Documentation](./api-documentation.md)** - API endpoints and request/response schemas
- **[Architecture](./architecture.md)** - System architecture and component interactions
- **[API Flows](./api-flows.md)** - Sequence diagrams showing frontend-to-backend interactions
- **[Development Guide](./development.md)** - Setup and development workflows

## Keeping Documentation Up to Date

### Automated Tools

1. **ERD Generation**: The ERD is manually maintained in `api/ERD.md`. To update:
   - Modify the Mermaid diagram when schema changes
   - Run `python api/scripts/validate_erd.py` to check consistency

2. **API Documentation**: 
   - FastAPI automatically generates Swagger docs at `/docs` and ReDoc at `/redoc`
   - These are always up-to-date with the code
   - Access them when the API server is running

3. **Schema Validation**:
   - Run `python api/scripts/validate_schemas.py` to ensure models match schemas

### Manual Updates Required

- API flow diagrams (when new features are added)
- Architecture diagrams (when system structure changes)
- Development guide (when setup process changes)

## Viewing Documentation

- **Mermaid Diagrams**: View in GitHub, VS Code with Mermaid extension, or [Mermaid Live Editor](https://mermaid.live)
- **API Docs**: Start the API server and visit `http://localhost:8000/docs`
- **Markdown**: View in any Markdown viewer or GitHub

