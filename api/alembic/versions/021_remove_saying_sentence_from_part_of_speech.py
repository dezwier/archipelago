"""Remove Saying and Sentence from part_of_speech

Revision ID: 021_remove_saying_sentence
Revises: 020_rename_card_to_lemma
Create Date: 2024-12-23 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '021_remove_saying_sentence'
down_revision = '020_rename_card_to_lemma'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Update all 'Saying' and 'Sentence' values to NULL (missing)
    connection = op.get_bind()
    connection.execute(
        sa.text("""
            UPDATE concept
            SET part_of_speech = NULL
            WHERE LOWER(TRIM(part_of_speech)) IN ('saying', 'sentence')
        """)
    )


def downgrade() -> None:
    # Cannot restore the original values, so downgrade does nothing
    # The data has been lost (converted to NULL)
    pass



