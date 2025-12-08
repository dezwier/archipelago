"""Extract images from concept table into Image table

Revision ID: 009_extract_images_to_image_table
Revises: 008_add_internal_name_to_concept
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '009_extract_images'
down_revision = '008_add_internal_name_to_concept'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create images table
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
    
    # Migrate existing image URLs from concept table to images table
    connection = op.get_bind()
    
    # Migrate image_path_1 (set as primary)
    connection.execute(
        sa.text("""
            INSERT INTO images (concept_id, url, image_type, is_primary, source, created_at)
            SELECT id, image_path_1, 'illustration', true, 'google', NOW()
            FROM concept
            WHERE image_path_1 IS NOT NULL AND image_path_1 != ''
        """)
    )
    
    # Migrate image_path_2
    connection.execute(
        sa.text("""
            INSERT INTO images (concept_id, url, image_type, is_primary, source, created_at)
            SELECT id, image_path_2, 'illustration', false, 'google', NOW()
            FROM concept
            WHERE image_path_2 IS NOT NULL AND image_path_2 != ''
        """)
    )
    
    # Migrate image_path_3
    connection.execute(
        sa.text("""
            INSERT INTO images (concept_id, url, image_type, is_primary, source, created_at)
            SELECT id, image_path_3, 'illustration', false, 'google', NOW()
            FROM concept
            WHERE image_path_3 IS NOT NULL AND image_path_3 != ''
        """)
    )
    
    # Migrate image_path_4
    connection.execute(
        sa.text("""
            INSERT INTO images (concept_id, url, image_type, is_primary, source, created_at)
            SELECT id, image_path_4, 'illustration', false, 'google', NOW()
            FROM concept
            WHERE image_path_4 IS NOT NULL AND image_path_4 != ''
        """)
    )
    
    # Drop image_path columns from concept table
    op.drop_column('concept', 'image_path_1')
    op.drop_column('concept', 'image_path_2')
    op.drop_column('concept', 'image_path_3')
    op.drop_column('concept', 'image_path_4')


def downgrade() -> None:
    # Add image_path columns back to concept table
    op.add_column('concept', sa.Column('image_path_1', sa.String(), nullable=True))
    op.add_column('concept', sa.Column('image_path_2', sa.String(), nullable=True))
    op.add_column('concept', sa.Column('image_path_3', sa.String(), nullable=True))
    op.add_column('concept', sa.Column('image_path_4', sa.String(), nullable=True))
    
    # Migrate images back to concept table (only primary and first 3 non-primary)
    connection = op.get_bind()
    
    # Get primary image as image_path_1
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_path_1 = (
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
    
    # Get non-primary images for image_path_2, 3, 4
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_path_2 = (
                SELECT url
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
                ORDER BY images.created_at
                LIMIT 1 OFFSET 0
            )
            WHERE EXISTS (
                SELECT 1
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
            )
        """)
    )
    
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_path_3 = (
                SELECT url
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
                ORDER BY images.created_at
                LIMIT 1 OFFSET 1
            )
            WHERE EXISTS (
                SELECT 1
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
                ORDER BY images.created_at
                OFFSET 1
                LIMIT 1
            )
        """)
    )
    
    connection.execute(
        sa.text("""
            UPDATE concept
            SET image_path_4 = (
                SELECT url
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
                ORDER BY images.created_at
                LIMIT 1 OFFSET 2
            )
            WHERE EXISTS (
                SELECT 1
                FROM images
                WHERE images.concept_id = concept.id
                AND images.is_primary = false
                ORDER BY images.created_at
                OFFSET 2
                LIMIT 1
            )
        """)
    )
    
    # Drop images table
    op.drop_index(op.f('ix_images_concept_id'), table_name='images')
    op.drop_table('images')

