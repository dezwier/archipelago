"""Create user_topic table

Revision ID: 040_create_user_topic_table
Revises: 039_update_topic_table_fields
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '040_create_user_topic_table'
down_revision = '039_update_topic_table_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create user_topic junction table for topic subscriptions."""
    op.create_table(
        'user_topic',
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('topic_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ),
        sa.ForeignKeyConstraint(['topic_id'], ['topic.id'], ),
        sa.PrimaryKeyConstraint('user_id', 'topic_id')
    )


def downgrade() -> None:
    """Drop user_topic table."""
    op.drop_table('user_topic')

