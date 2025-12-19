"""Cleanup any remaining references to images table

Revision ID: 028_cleanup_images
Revises: 027_drop_images
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '028_cleanup_images'
down_revision = '027_drop_images'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Clean up any remaining references to the images table.
    This migration ensures that:
    1. Any remaining foreign key constraints on the images table are dropped
    2. The images table is dropped if it still exists
    3. Any indexes on the images table are dropped
    4. Any foreign key constraints on other tables that reference images are dropped
    """
    # Drop any foreign key constraints on the images table (if it exists)
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
                
                -- Drop any indexes on the images table
                FOR r IN (
                    SELECT indexname
                    FROM pg_indexes
                    WHERE tablename = 'images'
                    AND schemaname = 'public'
                ) LOOP
                    EXECUTE 'DROP INDEX IF EXISTS ' || quote_ident(r.indexname);
                END LOOP;
            END IF;
        END $$;
    """))
    
    # Drop the table if it exists
    op.execute(sa.text("DROP TABLE IF EXISTS images"))
    
    # Also check for any foreign key constraints on other tables that reference images
    # (though this shouldn't exist, but just to be safe)
    # Use pg_constraint to find foreign keys that reference the images table
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
            images_oid OID;
        BEGIN
            -- Get the OID of the images table if it exists
            SELECT oid INTO images_oid
            FROM pg_class
            WHERE relname = 'images'
            AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
            
            -- Only proceed if images table exists (or existed)
            IF images_oid IS NOT NULL THEN
                FOR r IN (
                    SELECT 
                        conrelid::regclass::text AS table_name,
                        conname AS constraint_name
                    FROM pg_constraint
                    WHERE contype = 'f'
                    AND confrelid = images_oid
                ) LOOP
                    EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                            ' DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
                END LOOP;
            END IF;
        END $$;
    """))


def downgrade() -> None:
    # This migration only cleans up, so downgrade does nothing
    # The images table was already dropped in migration 027
    pass

