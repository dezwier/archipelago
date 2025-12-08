"""Add internal_name column to concept table

Revision ID: 008_add_internal_name_to_concept
Revises: 007_add_card_unique_constraint
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '008_add_internal_name_to_concept'
down_revision = '007_add_card_unique_constraint'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add internal_name column to concept table (nullable initially)
    op.add_column('concept', sa.Column('internal_name', sa.String(), nullable=True))
    
    # Populate existing records with English translations from their cards
    connection = op.get_bind()
    
    # Update concepts that have English cards
    connection.execute(
        sa.text("""
            UPDATE concept
            SET internal_name = (
                SELECT translation
                FROM cards
                WHERE cards.concept_id = concept.id
                AND cards.language_code = 'en'
                LIMIT 1
            )
            WHERE EXISTS (
                SELECT 1
                FROM cards
                WHERE cards.concept_id = concept.id
                AND cards.language_code = 'en'
            )
        """)
    )
    
    # For concepts without English cards, use the first available card's translation
    connection.execute(
        sa.text("""
            UPDATE concept
            SET internal_name = (
                SELECT translation
                FROM cards
                WHERE cards.concept_id = concept.id
                ORDER BY cards.id
                LIMIT 1
            )
            WHERE internal_name IS NULL
            AND EXISTS (
                SELECT 1
                FROM cards
                WHERE cards.concept_id = concept.id
            )
        """)
    )


def downgrade() -> None:
    # Drop internal_name column from concept table
    op.drop_column('concept', 'internal_name')

