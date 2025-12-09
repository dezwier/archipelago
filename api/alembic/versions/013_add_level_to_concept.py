"""Add level field to concept table

Revision ID: 013_add_level_to_concept
Revises: 012_enforce_card_concept_fk
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '013_add_level_to_concept'
down_revision = '012_enforce_card_concept_fk'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add level column to concept table
    # Using String(2) to store CEFR levels: A1, A2, B1, B2, C1, C2
    op.add_column('concept', 
                   sa.Column('level', sa.String(length=2), nullable=True))


def downgrade() -> None:
    # Remove level column from concept table
    op.drop_column('concept', 'level')

