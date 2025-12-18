"""Drop images table

Revision ID: 027_drop_images
Revises: 026_add_is_phrase
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '027_drop_images'
down_revision = '026_add_is_phrase'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop the images table
    op.drop_index(op.f('ix_images_concept_id'), table_name='images')
    op.drop_table('images')


def downgrade() -> None:
    # Recreate images table (for rollback purposes)
    op.create_table(
        'images',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('concept_id', sa.Integer(), nullable=False),
        sa.Column('url', sa.String(), nullable=False),
        sa.Column('image_type', sa.String(), nullable=True),
        sa.Column('is_primary', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('confidence_score', sa.Float(), nullable=True),
        sa.Column('alt_text', sa.String(), nullable=True),
        sa.Column('source', sa.String(), nullable=True),
        sa.Column('licence', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['concept_id'], ['concept.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_images_concept_id'), 'images', ['concept_id'], unique=False)

