from fastapi import FastAPI, Request, status, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import logging
import os
import traceback
from app.core.config import settings
from app.core.database import init_db
from app.core.exceptions import (
    ArchipelagoException,
    ValidationError,
    NotFoundError,
    ConflictError,
    AuthenticationError,
    AuthorizationError
)

# Import models to register them with SQLModel
from app.models import models  # noqa: F401

# Import API router
from app.api.v1 import api_router

logger = logging.getLogger(__name__)

# Check if we're in development mode
IS_DEVELOPMENT = os.getenv("ENVIRONMENT", "production").lower() in ("development", "dev", "local")

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

# Add exception handler for custom application exceptions
@app.exception_handler(ArchipelagoException)
async def archipelago_exception_handler(request: Request, exc: ArchipelagoException):
    """Handle custom application exceptions."""
    if isinstance(exc, ValidationError):
        status_code = status.HTTP_400_BAD_REQUEST
    elif isinstance(exc, NotFoundError):
        status_code = status.HTTP_404_NOT_FOUND
    elif isinstance(exc, ConflictError):
        status_code = status.HTTP_409_CONFLICT
    elif isinstance(exc, AuthenticationError):
        status_code = status.HTTP_401_UNAUTHORIZED
    elif isinstance(exc, AuthorizationError):
        status_code = status.HTTP_403_FORBIDDEN
    else:
        status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    
    logger.warning(f"Application exception on {request.method} {request.url.path}: {type(exc).__name__}: {str(exc)}")
    return JSONResponse(
        status_code=status_code,
        content={"detail": str(exc), "type": type(exc).__name__},
    )

# Add global exception handler for unhandled errors
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch all unhandled exceptions to prevent 502 errors."""
    # Log full traceback
    logger.error(f"Unhandled exception on {request.method} {request.url.path}", exc_info=exc)
    
    # In development, show full error details
    if IS_DEVELOPMENT:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "detail": str(exc),
                "type": type(exc).__name__,
                "traceback": traceback.format_exc()
            },
        )
    else:
        # In production, return generic message
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "detail": "An internal server error occurred. Please try again later.",
                "type": "InternalServerError"
            },
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


# Include API router
app.include_router(api_router, prefix=settings.api_v1_prefix)

# Mount static files for assets
# Use ASSETS_PATH if configured (Railway volumes), otherwise use api/assets
if settings.assets_path:
    assets_dir = Path(settings.assets_path)
else:
    api_root = Path(__file__).parent.parent.parent
    assets_dir = api_root / "assets"

assets_dir.mkdir(parents=True, exist_ok=True)
logger.info(f"Mounting static files from: {assets_dir}")
app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")

