from alembic import context
from sqlmodel import SQLModel
from app.core.config import settings
from app.core.database import engine

# Import all models here so Alembic can detect them
from app.models.models import (
    Topic,
    Concept,
    Language,
    Lemma,
    UserLemma,
    User,
    Exercise,
)

# this is the Alembic Config object
config = context.config

# Set the sqlalchemy.url from our settings
# Ensure postgres:// is converted to postgresql:// for SQLAlchemy
db_url = settings.database_url
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)
config.set_main_option("sqlalchemy.url", db_url)

# Import metadata for autogenerate
target_metadata = SQLModel.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    connectable = engine

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

