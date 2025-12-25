# Documentation Tools and Visualization

This document describes tools and techniques for visualizing and maintaining documentation in the Archipelago project.

## Current Tools

### 1. Mermaid Diagrams

**Location**: `api/ERD.md`, `docs/api-flows.md`

**What it is**: Text-based diagramming syntax that renders as visual diagrams

**Advantages**:
- Version controlled (text files)
- Easy to edit
- Renders on GitHub automatically
- Works in VS Code with Mermaid extension
- No external dependencies

**Viewing**:
- GitHub: Automatically renders
- VS Code: Install "Markdown Preview Mermaid Support" extension
- Online: [Mermaid Live Editor](https://mermaid.live)
- CLI: `npm install -g @mermaid-js/mermaid-cli` then `mmdc -i ERD.md -o ERD.png`

**Updating**: Edit the `.md` file with Mermaid syntax

### 2. FastAPI Auto-Generated Docs

**Location**: `http://localhost:8000/docs` (Swagger) and `/redoc` (ReDoc)

**What it is**: Interactive API documentation automatically generated from code

**Advantages**:
- Always up-to-date (generated from code)
- Interactive (can test endpoints)
- Shows request/response schemas
- No manual maintenance needed

**Access**: Start the API server and visit the URLs above

### 3. Validation Scripts

**Location**: `api/scripts/`

**Scripts**:
- `validate_erd.py` - Validates ERD.md matches database models
- `validate_schemas.py` - Validates schemas are properly structured

**Usage**:
```bash
cd api
python scripts/validate_erd.py
python scripts/validate_schemas.py
```

## Recommended Additional Tools

### 1. Database Schema Visualization

#### Option A: ERAlchemy (Python)
```bash
pip install eralchemy
eralchemy -i 'postgresql://user:pass@localhost/dbname' -o schema.png
```

#### Option B: pgAdmin
- Built-in ERD tool
- Visual database browser
- Can export ERD diagrams

#### Option C: DBeaver
- Free database tool
- ERD visualization
- Cross-platform

### 2. API Flow Diagrams

#### Option A: PlantUML (Recommended)
- Text-based UML diagrams
- Can be embedded in Markdown
- Renders on GitHub with plugin
- More powerful than Mermaid for sequence diagrams

**Example**:
```plantuml
@startuml
User -> Flutter: Action
Flutter -> API: HTTP Request
API -> DB: Query
DB --> API: Data
API --> Flutter: Response
Flutter --> User: Update UI
@enduml
```

**Setup**:
1. Install PlantUML: `brew install plantuml` (macOS) or download from [plantuml.com](https://plantuml.com)
2. VS Code extension: "PlantUML"
3. GitHub: Use [PlantUML GitHub Action](https://github.com/marketplace/actions/plantuml-render)

#### Option B: Draw.io / diagrams.net
- Visual diagram editor
- Can export to SVG/PNG
- Free and open source
- Can be integrated with GitHub

**Workflow**:
1. Create diagrams in [diagrams.net](https://app.diagrams.net)
2. Save as `.drawio` files in `docs/diagrams/`
3. Export to PNG/SVG for embedding in docs

### 3. Architecture Diagrams

#### Option A: C4 Model
- Standard for software architecture
- Multiple levels (Context, Container, Component, Code)
- Tools: [Structurizr](https://structurizr.com) or [C4-PlantUML](https://github.com/plantuml/plantuml-stdlib)

#### Option B: Mermaid Architecture Diagrams
Mermaid supports architecture diagrams:
```mermaid
graph TB
    A[Flutter App] --> B[FastAPI]
    B --> C[PostgreSQL]
    B --> D[AI Services]
```

### 4. Code Documentation

#### Option A: Sphinx (Python)
- Auto-generate docs from docstrings
- Can document API, models, services
- Outputs HTML/PDF

**Setup**:
```bash
pip install sphinx sphinx-rtd-theme
sphinx-quickstart docs/sphinx
```

#### Option B: Dartdoc (Flutter)
- Auto-generate docs from Dart code
- Similar to Javadoc/JSDoc

**Usage**:
```bash
cd app
dart doc
```

### 5. API Contract Testing

#### Option A: OpenAPI/Swagger Export
FastAPI can export OpenAPI schema:
```python
# In main.py
@app.get("/openapi.json")
async def get_openapi():
    return app.openapi()
```

Then use tools like:
- [Swagger Editor](https://editor.swagger.io) - Visual API editor
- [Postman](https://www.postman.com) - API testing and documentation
- [Insomnia](https://insomnia.rest) - API client with documentation

#### Option B: Pact
- Contract testing between frontend and backend
- Ensures API contracts don't break
- Can generate documentation from contracts

### 6. Database Migration Visualization

#### Alembic Migration Graph
```bash
cd api
alembic history --verbose
```

Can create a visual graph of migrations:
```bash
pip install alembic-graph
alembic-graph -o migration_graph.png
```

## Automated Documentation Generation

### GitHub Actions Workflow

Create `.github/workflows/docs.yml`:

```yaml
name: Update Documentation

on:
  push:
    branches: [main]
    paths:
      - 'api/app/models/**'
      - 'api/app/api/**'
      - 'api/ERD.md'

jobs:
  validate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
      - name: Install dependencies
        run: |
          cd api
          pip install -r requirements.txt
      - name: Validate ERD
        run: |
          cd api
          python scripts/validate_erd.py
      - name: Generate ERD image
        run: |
          npm install -g @mermaid-js/mermaid-cli
          mmdc -i api/ERD.md -o docs/images/erd.png
```

### Pre-commit Hooks

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: validate-erd
        name: Validate ERD
        entry: python api/scripts/validate_erd.py
        language: system
        files: ^api/(app/models/|ERD\.md)
```

Install: `pip install pre-commit && pre-commit install`

## Keeping Things Up to Date

### Manual Updates Required

1. **ERD.md**: Update when models change
   - Run `validate_erd.py` to check consistency
   - Update Mermaid diagram manually

2. **API Flows**: Update when new features are added
   - Add new sequence diagrams
   - Update endpoint mapping table

3. **Architecture**: Update when system structure changes
   - Update component diagrams
   - Update technology stack

### Automated Updates

1. **FastAPI Docs**: Always up-to-date (no action needed)
2. **Model Validation**: Run scripts before committing
3. **Schema Validation**: Run scripts before committing

## Recommended Workflow

1. **When adding a new model**:
   - Update `api/app/models/`
   - Create Alembic migration
   - Update `api/ERD.md`
   - Run `validate_erd.py`
   - Update `docs/data-model.md`

2. **When adding a new API endpoint**:
   - Add endpoint in `api/app/api/v1/endpoints/`
   - FastAPI docs auto-update
   - Update `docs/api-flows.md` if it's a new flow
   - Update `docs/api-documentation.md` overview

3. **When adding a new feature**:
   - Update `docs/architecture.md` if structure changes
   - Add flow diagram to `docs/api-flows.md`
   - Update relevant service documentation

## Visualization Tools Comparison

| Tool | Type | Best For | Maintenance |
|------|------|----------|-------------|
| Mermaid | Text-based | ERDs, simple flows | Low (text files) |
| PlantUML | Text-based | Complex UML diagrams | Low (text files) |
| Draw.io | Visual | Architecture diagrams | Medium (manual updates) |
| FastAPI Docs | Auto-generated | API reference | None (automatic) |
| ERAlchemy | Auto-generated | Database ERD | Low (run script) |

## Best Practices

1. **Prefer text-based diagrams** (Mermaid, PlantUML) for version control
2. **Use auto-generated docs** where possible (FastAPI, Dartdoc)
3. **Validate before committing** (run validation scripts)
4. **Keep diagrams simple** - focus on clarity over completeness
5. **Update docs with code changes** - don't let them drift apart
6. **Use CI/CD** to catch documentation inconsistencies

## Resources

- [Mermaid Documentation](https://mermaid.js.org)
- [PlantUML Documentation](https://plantuml.com)
- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [C4 Model](https://c4model.com)
- [Structurizr](https://structurizr.com)

