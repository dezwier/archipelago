"""Add icon field to topic table

Revision ID: 022_add_icon_to_topic
Revises: 021_remove_saying_sentence
Create Date: 2024-12-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '022_add_icon_to_topic'
down_revision = '021_remove_saying_sentence'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add icon column (nullable, single emoji character)
    op.add_column('topic', sa.Column('icon', sa.String(length=10), nullable=True))


def downgrade() -> None:
    # Remove icon column
    op.drop_column('topic', 'icon')
