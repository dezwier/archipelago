"""Update topic table fields

Revision ID: 039_update_topic_table_fields
Revises: 038_add_user_profile_fields
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '039_update_topic_table_fields'
down_revision = '038_add_user_profile_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Add visibility and liked fields, rename user_id to created_by_user_id."""
    # Add visibility column (enum, default 'private')
    op.add_column('topic', sa.Column('visibility', sa.String(), nullable=False, server_default='private'))
    
    # Add liked column (int, default 0)
    op.add_column('topic', sa.Column('liked', sa.Integer(), nullable=False, server_default='0'))
    
    # Rename user_id to created_by_user_id
    op.alter_column('topic', 'user_id', new_column_name='created_by_user_id')


def downgrade() -> None:
    """Remove visibility and liked fields, rename created_by_user_id back to user_id."""
    # Rename created_by_user_id back to user_id
    op.alter_column('topic', 'created_by_user_id', new_column_name='user_id')
    
    # Drop liked column
    op.drop_column('topic', 'liked')
    
    # Drop visibility column
    op.drop_column('topic', 'visibility')

