from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import init_db

# Import models to register them with SQLModel
from app.models import models  # noqa: F401

app = FastAPI(title="Archipelago API", version="1.0.0")

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
    return {"message": "Archipelago API", "status": "running"}


@app.get("/health")
async def health():
    return {"status": "healthy"}

