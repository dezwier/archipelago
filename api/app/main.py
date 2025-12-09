from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
import logging
from app.core.config import settings
from app.core.database import init_db

# Import models to register them with SQLModel
from app.models import models  # noqa: F401

# Import routers
from app.api.v1.endpoints import auth, languages, vocabulary, concepts, cards, concept_generation, card_generation, topics

logger = logging.getLogger(__name__)

app = FastAPI(title="Archipelago API", version="1.0.0")

# Add exception handler for validation errors to log details
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Log validation errors with full details for debugging."""
    body = await request.body()
    logger.error(f"Validation error on {request.method} {request.url.path}")
    logger.error(f"Request body: {body.decode('utf-8') if body else 'empty'}")
    logger.error(f"Validation errors: {exc.errors()}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors(), "body": body.decode('utf-8') if body else None},
    )

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup."""
    init_db()


@app.get("/")
async def root():
    return {
        "message": "Archipelago API",
        "status": "running",
        "docs": {
            "swagger": "/docs",
            "redoc": "/redoc"
        }
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}


# Include routers
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(languages.router, prefix=settings.api_v1_prefix)
app.include_router(vocabulary.router, prefix=settings.api_v1_prefix)
app.include_router(concepts.router, prefix=settings.api_v1_prefix)
app.include_router(cards.router, prefix=settings.api_v1_prefix)
app.include_router(concept_generation.router, prefix=settings.api_v1_prefix)
app.include_router(card_generation.router, prefix=settings.api_v1_prefix)
app.include_router(topics.router, prefix=settings.api_v1_prefix)

