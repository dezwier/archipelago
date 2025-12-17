"""Add image_url field to concept table

Revision ID: 023_add_image_url_to_concept
Revises: 022_add_icon_to_topic
Create Date: 2024-12-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '023_add_image_url_to_concept'
down_revision = '022_add_icon_to_topic'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add image_url column to concept table
    op.add_column('concept', sa.Column('image_url', sa.String(), nullable=True))
    
    # Migrate existing image URLs from images table to concept.image_url
    # Priority: primary image first, then first image by created_at
    connection = op.get_bind()
    
    # First, update with primary images
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_url = (
                SELECT url
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = true
                ORDER BY images.created_at
                LIMIT 1
            )
            WHERE EXISTS (
                SELECT 1
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = true
            )
        """)
    )
    
    # Then, update concepts without primary images with their first image
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_url = (
                SELECT url
                FROM images
                WHERE images.concept_id = concept.id
                ORDER BY images.created_at
                LIMIT 1
            )
            WHERE image_url IS NULL
            AND EXISTS (
                SELECT 1
                FROM images
                WHERE images.concept_id = concept.id
            )
        """)
    )


def downgrade() -> None:
    # Remove image_url column
    op.drop_column('concept', 'image_url')




