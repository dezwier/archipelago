"""Add Portuguese and Arabic languages to languages table

Revision ID: 014_add_portuguese_arabic_languages
Revises: 013_add_level_to_concept
Create Date: 2024-12-19 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '014_add_pt_ar'
down_revision = '013_add_level_to_concept'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Insert Portuguese and Arabic into the languages table
    languages_table = sa.table(
        'languages',
        sa.column('code', sa.String),
        sa.column('name', sa.String)
    )
    
    op.bulk_insert(
        languages_table,
        [
            {'code': 'pt', 'name': 'Portuguese'},
            {'code': 'ar', 'name': 'Arabic'},
        ]
    )


def downgrade() -> None:
    # Remove Portuguese and Arabic from the languages table
    op.execute("DELETE FROM languages WHERE code IN ('pt', 'ar')")

