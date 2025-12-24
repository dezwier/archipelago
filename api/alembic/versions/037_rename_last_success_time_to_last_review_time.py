"""Rename last_success_time to last_review_time in user_lemma table

Revision ID: 037_rename_last_success_time_to_last_review_time
Revises: 036_lesson_fk_and_populate
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '037_rename_last_success_time'
down_revision = '036_lesson_fk_and_populate'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Rename last_success_time column to last_review_time in user_lemma table."""
    op.alter_column('user_lemma', 'last_success_time', new_column_name='last_review_time', existing_type=sa.DateTime(), existing_nullable=True)


def downgrade() -> None:
    """Rename last_review_time column back to last_success_time in user_lemma table."""
    op.alter_column('user_lemma', 'last_review_time', new_column_name='last_success_time', existing_type=sa.DateTime(), existing_nullable=True)

