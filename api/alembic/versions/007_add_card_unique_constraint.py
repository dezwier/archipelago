"""Add unique constraint on concept_id, language_code, and translation

Revision ID: 007_add_card_unique_constraint
Revises: 006_add_card_creation_time
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '007_add_card_unique_constraint'
down_revision = '006_add_card_creation_time'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # First, remove duplicate cards (keep the one with the lowest ID for each unique combination)
    # This uses a subquery to identify duplicates and deletes all but the one with the minimum ID
    connection = op.get_bind()
    
    # Delete duplicates, keeping only the card with the minimum ID for each (concept_id, language_code, translation) combination
    connection.execute(
        sa.text("""
            DELETE FROM cards
            WHERE id NOT IN (
                SELECT MIN(id)
                FROM cards
                GROUP BY concept_id, language_code, translation
            )
        """)
    )
    
    # Now add unique constraint on concept_id, language_code, and translation
    op.create_unique_constraint(
        'uq_card_concept_language_translation',
        'cards',
        ['concept_id', 'language_code', 'translation']
    )


def downgrade() -> None:
    # Drop unique constraint
    op.drop_constraint(
        'uq_card_concept_language_translation',
        'cards',
        type_='unique'
    )

