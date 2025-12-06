from sqlmodel import SQLModel, create_engine, Session
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Create database engine
# Railway provides DATABASE_URL automatically when you connect the database service
# Ensure the URL uses postgresql:// (not postgres://) for SQLAlchemy
db_url = settings.database_url
if db_url.startswith("postgres://"):
    # SQLAlchemy prefers postgresql:// over postgres://
    db_url = db_url.replace("postgres://", "postgresql://", 1)

logger.info(f"Connecting to database: {db_url[:20]}...")  # Log partial URL for debugging

engine = create_engine(
    db_url,
    echo=False,  # Set to False in production to reduce logs
    pool_pre_ping=True,  # Verify connections before using
    pool_size=5,
    max_overflow=10,
)


def get_session():
    """Dependency for getting database sessions."""
    with Session(engine) as session:
        yield session


def init_db():
    """Initialize database tables."""
    SQLModel.metadata.create_all(engine)

