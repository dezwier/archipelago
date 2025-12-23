"""Add lesson_id to exercise table

Revision ID: 035_add_lesson_id_to_exercise
Revises: 034_add_lesson_table
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '035_add_lesson_id_to_exercise'
down_revision = '034_add_lesson_table'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Add lesson_id column to exercise table with foreign key constraint.
    """
    # Add lesson_id column as nullable (existing exercises won't have a lesson)
    op.add_column('exercise', sa.Column('lesson_id', sa.Integer(), nullable=True))
    
    # Create foreign key constraint
    op.create_foreign_key(
        'exercise_lesson_id_fkey',
        'exercise',
        'lesson',
        ['lesson_id'],
        ['id']
    )
    
    # Create index on lesson_id for query performance
    op.create_index(op.f('ix_exercise_lesson_id'), 'exercise', ['lesson_id'], unique=False)


def downgrade() -> None:
    """
    Remove lesson_id column from exercise table.
    """
    op.drop_index(op.f('ix_exercise_lesson_id'), table_name='exercise')
    op.drop_constraint('exercise_lesson_id_fkey', 'exercise', type_='foreignkey')
    op.drop_column('exercise', 'lesson_id')

