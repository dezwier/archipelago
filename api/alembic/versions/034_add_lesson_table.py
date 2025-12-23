"""Add lesson table

Revision ID: 034_add_lesson_table
Revises: 033_rename_tables_to_singular
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '034_add_lesson_table'
down_revision = '033_rename_tables_to_singular'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Create lesson table to track lesson sessions.
    """
    op.create_table(
        'lesson',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('learning_language', sa.String(), nullable=False),
        sa.Column('kind', sa.String(), nullable=False),
        sa.Column('start_time', sa.DateTime(), nullable=False),
        sa.Column('end_time', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], name='lesson_user_id_fkey'),
        sa.PrimaryKeyConstraint('id', name='lesson_pkey'),
        sa.CheckConstraint(
            "kind IN ('new', 'learned', 'all')",
            name='lesson_kind_check'
        )
    )
    
    # Create index on user_id for query performance
    op.create_index(op.f('ix_lesson_user_id'), 'lesson', ['user_id'], unique=False)


def downgrade() -> None:
    """
    Drop lesson table.
    """
    op.drop_index(op.f('ix_lesson_user_id'), table_name='lesson')
    op.drop_table('lesson')

