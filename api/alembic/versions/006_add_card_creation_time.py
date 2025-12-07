"""Add creation_time field to cards table

Revision ID: 006_add_card_creation_time
Revises: 005_remove_internal_name
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '006_add_card_creation_time'
down_revision = '005_remove_internal_name'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add creation_time column to cards table
    # Use server_default to set current timestamp for existing records
    op.add_column('cards', sa.Column('creation_time', sa.DateTime(), nullable=False, server_default=sa.func.now()))


def downgrade() -> None:
    # Drop creation_time column from cards table
    op.drop_column('cards', 'creation_time')

