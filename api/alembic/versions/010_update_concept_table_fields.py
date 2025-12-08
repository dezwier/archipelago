"""Update concept table with new fields

Revision ID: 010_update_concept_table_fields
Revises: 009_extract_images
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '010_update_concept_table_fields'
down_revision = '009_extract_images'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename internal_name to term
    op.alter_column('concept', 'internal_name', new_column_name='term', existing_type=sa.String(), existing_nullable=True)
    
    # Add new columns
    op.add_column('concept', sa.Column('description', sa.Text(), nullable=True))
    op.add_column('concept', sa.Column('part_of_speech', sa.Text(), nullable=True))
    op.add_column('concept', sa.Column('frequency_bucket', sa.Text(), nullable=True))
    op.add_column('concept', sa.Column('status', sa.Text(), nullable=True))
    op.add_column('concept', sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')))
    op.add_column('concept', sa.Column('updated_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    # Remove new columns
    op.drop_column('concept', 'updated_at')
    op.drop_column('concept', 'created_at')
    op.drop_column('concept', 'status')
    op.drop_column('concept', 'frequency_bucket')
    op.drop_column('concept', 'part_of_speech')
    op.drop_column('concept', 'description')
    
    # Rename term back to internal_name
    op.alter_column('concept', 'term', new_column_name='internal_name', existing_type=sa.String(), existing_nullable=True)

