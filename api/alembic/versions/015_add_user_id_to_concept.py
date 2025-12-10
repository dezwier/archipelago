"""Add user_id field to concept table

Revision ID: 015_add_user_id_to_concept
Revises: 014_add_pt_ar
Create Date: 2024-12-19 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '015_add_user_id_to_concept'
down_revision = '014_add_pt_ar'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add user_id column to concept table
    op.add_column('concept', sa.Column('user_id', sa.Integer(), nullable=True))
    # Add foreign key constraint
    op.create_foreign_key(
        'fk_concept_user_id',
        'concept',
        'users',
        ['user_id'],
        ['id']
    )
    # Add index for better query performance
    op.create_index(op.f('ix_concept_user_id'), 'concept', ['user_id'], unique=False)


def downgrade() -> None:
    # Remove index
    op.drop_index(op.f('ix_concept_user_id'), table_name='concept')
    # Remove foreign key constraint
    op.drop_constraint('fk_concept_user_id', 'concept', type_='foreignkey')
    # Remove column
    op.drop_column('concept', 'user_id')

