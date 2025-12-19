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
    # First, drop any foreign key constraints explicitly to avoid issues
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            -- Check if images table exists
            IF EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'images'
            ) THEN
                -- Drop any foreign key constraints on the images table
                FOR r IN (
                    SELECT conname
                    FROM pg_constraint
                    WHERE conrelid = 'images'::regclass
                    AND contype = 'f'
                ) LOOP
                    EXECUTE 'ALTER TABLE images DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
                END LOOP;
            END IF;
        END $$;
    """))
    
    # Drop the index if it exists (before dropping table)
    op.execute(sa.text("DROP INDEX IF EXISTS ix_images_concept_id"))
    
    # Drop the table (this will also drop any remaining constraints)
    op.execute(sa.text("DROP TABLE IF EXISTS images"))


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

