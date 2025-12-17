"""Add is_phrase column to concept table

Revision ID: 026_add_is_phrase
Revises: 025_trim_lemma_terms
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '026_add_is_phrase'
down_revision = '025_trim_lemma_terms'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add is_phrase column to concept table
    op.add_column('concept', sa.Column('is_phrase', sa.Boolean(), nullable=False, server_default='false'))
    
    # Update existing data: set is_phrase = 0 (false) if user_id is NULL, 1 (true) if user_id is present
    connection = op.get_bind()
    connection.execute(
        sa.text("""
            UPDATE concept
            SET is_phrase = CASE 
                WHEN user_id IS NULL THEN false
                ELSE true
            END
        """)
    )


def downgrade() -> None:
    # Remove is_phrase column
    op.drop_column('concept', 'is_phrase')



