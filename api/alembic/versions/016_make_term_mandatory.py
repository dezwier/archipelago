"""Make term mandatory in concept table

Revision ID: 016_make_term_mandatory
Revises: 015_add_user_id_to_concept
Create Date: 2024-12-20 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '016_make_term_mandatory'
down_revision = '015_add_user_id_to_concept'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Delete images associated with concepts that don't have a term
    # (term is NULL or empty string)
    op.execute(sa.text("""
        DELETE FROM images
        WHERE concept_id IN (
            SELECT id FROM concept
            WHERE term IS NULL OR term = '' OR TRIM(term) = ''
        )
    """))
    
    # Step 2: Delete cards associated with concepts that don't have a term
    # (CASCADE should handle this, but being explicit for safety)
    op.execute(sa.text("""
        DELETE FROM card
        WHERE concept_id IN (
            SELECT id FROM concept
            WHERE term IS NULL OR term = '' OR TRIM(term) = ''
        )
    """))
    
    # Step 3: Delete concepts that don't have a term
    op.execute(sa.text("""
        DELETE FROM concept
        WHERE term IS NULL OR term = '' OR TRIM(term) = ''
    """))
    
    # Step 4: Make term column NOT NULL
    op.alter_column('concept', 'term',
                   existing_type=sa.String(),
                   nullable=False)


def downgrade() -> None:
    # Make term column nullable again
    op.alter_column('concept', 'term',
                   existing_type=sa.String(),
                   nullable=True)














