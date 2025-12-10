"""Enforce unique constraint on card table (concept_id, language_code, term)

Revision ID: 017_enforce_card_uq
Revises: 016_make_term_mandatory
Create Date: 2024-12-20 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '017_enforce_card_uq'
down_revision = '016_make_term_mandatory'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Remove any duplicate cards (keep the one with the lowest ID for each unique combination)
    # This ensures data integrity before we enforce the constraint
    connection = op.get_bind()
    
    # Delete duplicates, keeping only the card with the minimum ID for each (concept_id, language_code, term) combination
    connection.execute(
        sa.text("""
            DELETE FROM card
            WHERE id NOT IN (
                SELECT MIN(id)
                FROM card
                GROUP BY concept_id, language_code, term
            )
        """)
    )
    
    # Step 2: Drop the constraint if it exists (to avoid errors if it already exists)
    # Use raw SQL to drop if exists (PostgreSQL syntax)
    connection.execute(
        sa.text("""
            ALTER TABLE card DROP CONSTRAINT IF EXISTS uq_card_concept_language_term;
        """)
    )
    
    # Step 3: Create the unique constraint
    op.create_unique_constraint(
        'uq_card_concept_language_term',
        'card',
        ['concept_id', 'language_code', 'term']
    )


def downgrade() -> None:
    # Drop the unique constraint
    op.drop_constraint(
        'uq_card_concept_language_term',
        'card',
        type_='unique'
    )

