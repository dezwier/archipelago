from sqlmodel import SQLModel, create_engine, Session
from app.core.config import settings

# Create database engine
# Railway provides DATABASE_URL automatically when you connect the database service
engine = create_engine(
    settings.database_url,
    echo=True,  # Set to False in production
    pool_pre_ping=True,  # Verify connections before using
)


def get_session():
    """Dependency for getting database sessions."""
    with Session(engine) as session:
        yield session


def init_db():
    """Initialize database tables."""
    SQLModel.metadata.create_all(engine)

