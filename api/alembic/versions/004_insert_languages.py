"""Insert initial languages into languages table

Revision ID: 004_insert_languages
Revises: 003_rename_gmail_to_email
Create Date: 2024-01-04 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '004_insert_languages'
down_revision = '003_rename_gmail_to_email'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Insert languages into the languages table
    languages_table = sa.table(
        'languages',
        sa.column('code', sa.String),
        sa.column('name', sa.String)
    )
    
    op.bulk_insert(
        languages_table,
        [
            {'code': 'en', 'name': 'English'},
            {'code': 'es', 'name': 'Spanish'},
            {'code': 'it', 'name': 'Italian'},
            {'code': 'fr', 'name': 'French'},
            {'code': 'de', 'name': 'German'},
            {'code': 'jp', 'name': 'Japanese'},
            {'code': 'nl', 'name': 'Dutch'},
            {'code': 'lt', 'name': 'Lithuanian'},
        ]
    )


def downgrade() -> None:
    # Remove the inserted languages
    op.execute("DELETE FROM languages WHERE code IN ('en', 'es', 'it', 'fr', 'de', 'jp', 'nl', 'lt')")

