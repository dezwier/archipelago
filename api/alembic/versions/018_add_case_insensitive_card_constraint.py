"""Add case-insensitive unique constraint on card table

Revision ID: 018_case_insensitive_uq
Revises: 017_enforce_card_uq
Create Date: 2024-12-20 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '018_case_insensitive_uq'
down_revision = '017_enforce_card_uq'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Normalize all terms (trim whitespace)
    connection = op.get_bind()
    connection.execute(
        sa.text("""
            UPDATE card
            SET term = TRIM(term)
            WHERE term != TRIM(term)
        """)
    )
    
    # Step 2: Remove duplicates based on case-insensitive comparison
    # Keep the card with the lowest ID, delete others
    connection.execute(
        sa.text("""
            DELETE FROM card
            WHERE id NOT IN (
                SELECT MIN(id)
                FROM card
                GROUP BY concept_id, language_code, LOWER(TRIM(term))
            )
        """)
    )
    
    # Step 3: Drop the existing case-sensitive constraint
    connection.execute(
        sa.text("""
            ALTER TABLE card DROP CONSTRAINT IF EXISTS uq_card_concept_language_term;
        """)
    )
    
    # Step 4: Create a case-insensitive unique constraint using a unique index
    # This prevents duplicates like "Abandon" and "abandon"
    connection.execute(
        sa.text("""
            CREATE UNIQUE INDEX uq_card_concept_language_term_ci 
            ON card (concept_id, language_code, LOWER(TRIM(term)));
        """)
    )


def downgrade() -> None:
    # Drop the case-insensitive unique index
    op.drop_index('uq_card_concept_language_term_ci', table_name='card')
    
    # Recreate the case-sensitive constraint
    op.create_unique_constraint(
        'uq_card_concept_language_term',
        'card',
        ['concept_id', 'language_code', 'term']
    )














