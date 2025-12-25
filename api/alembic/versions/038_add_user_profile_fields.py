"""Add user profile fields and Leitner algorithm configuration

Revision ID: 038_add_user_profile_fields
Revises: 037_rename_last_success_time_to_last_review_time
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '038_add_user_profile_fields'
down_revision = '037_rename_last_success_time'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Add profile fields and Leitner algorithm configuration to user table."""
    # Add full_name column (nullable)
    op.add_column('user', sa.Column('full_name', sa.String(), nullable=True))
    
    # Add image_url column (nullable)
    op.add_column('user', sa.Column('image_url', sa.String(), nullable=True))
    
    # Add leitner_max_bins column (non-nullable with default)
    op.add_column('user', sa.Column('leitner_max_bins', sa.Integer(), nullable=False, server_default='7'))
    
    # Add leitner_algorithm column (non-nullable with default)
    op.add_column('user', sa.Column('leitner_algorithm', sa.String(), nullable=False, server_default='fibonacci'))
    
    # Add leitner_interval_factor column (nullable, no default)
    op.add_column('user', sa.Column('leitner_interval_factor', sa.Float(), nullable=True))
    
    # Add leitner_interval_start column (non-nullable with default)
    op.add_column('user', sa.Column('leitner_interval_start', sa.Integer(), nullable=False, server_default='23'))


def downgrade() -> None:
    """Remove profile fields and Leitner algorithm configuration from user table."""
    op.drop_column('user', 'leitner_interval_start')
    op.drop_column('user', 'leitner_interval_factor')
    op.drop_column('user', 'leitner_algorithm')
    op.drop_column('user', 'leitner_max_bins')
    op.drop_column('user', 'image_url')
    op.drop_column('user', 'full_name')

