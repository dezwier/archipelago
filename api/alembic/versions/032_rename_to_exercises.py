"""Rename practices table to exercises

Revision ID: 032_rename_to_exercises
Revises: 031_revise_practice_table
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '032_rename_to_exercises'
down_revision = '031_revise_practice_table'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Rename practices table to exercises and update all related constraints and indexes.
    """
    
    # Step 1: Rename table from practices to exercises
    op.rename_table('practices', 'exercises')
    
    # Step 2: Rename foreign key constraints
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercises'::regclass
                AND contype = 'f'
                AND conname LIKE 'practices_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercises RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'practices_', 'exercises_');
            END LOOP;
        END $$;
    """))
    
    # Step 3: Rename indexes
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_user_lemma_id"))
    op.create_index(op.f('ix_exercises_user_lemma_id'), 'exercises', ['user_lemma_id'], unique=False)
    
    # Step 4: Rename CHECK constraint if it exists
    op.execute(sa.text("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conrelid = 'exercises'::regclass 
                AND conname = 'practices_result_check'
            ) THEN
                ALTER TABLE exercises RENAME CONSTRAINT practices_result_check TO exercises_result_check;
            END IF;
        END $$;
    """))


def downgrade() -> None:
    """
    Revert the changes: rename exercises back to practices.
    """
    
    # Step 1: Rename CHECK constraint back
    op.execute(sa.text("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conrelid = 'exercises'::regclass 
                AND conname = 'exercises_result_check'
            ) THEN
                ALTER TABLE exercises RENAME CONSTRAINT exercises_result_check TO practices_result_check;
            END IF;
        END $$;
    """))
    
    # Step 2: Rename indexes back
    op.execute(sa.text("DROP INDEX IF EXISTS ix_exercises_user_lemma_id"))
    op.create_index(op.f('ix_practices_user_lemma_id'), 'practices', ['user_lemma_id'], unique=False)
    
    # Step 3: Rename foreign key constraints back
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercises'::regclass
                AND contype = 'f'
                AND conname LIKE 'exercises_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercises RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercises_', 'practices_');
            END LOOP;
        END $$;
    """))
    
    # Step 4: Rename table from exercises back to practices
    op.rename_table('exercises', 'practices')

