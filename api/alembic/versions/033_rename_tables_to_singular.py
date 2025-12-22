"""Rename tables to singular form

Revision ID: 033_rename_tables_to_singular
Revises: 032_rename_to_exercises
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '033_rename_tables_to_singular'
down_revision = '032_rename_to_exercises'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Rename tables from plural to singular:
    - users -> user
    - exercises -> exercise
    - user_lemmas -> user_lemma
    
    PostgreSQL automatically updates foreign key references when tables are renamed.
    We just need to rename the tables, indexes, and constraint names.
    """
    
    # Step 1: Rename user_lemmas to user_lemma (do this first as it's referenced by exercises)
    op.rename_table('user_lemmas', 'user_lemma')
    
    # Step 2: Rename indexes for user_lemma
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'user_lemma'
                AND indexname LIKE 'ix_user_lemmas_%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_user_lemmas_', 'ix_user_lemma_');
            END LOOP;
        END $$;
    """))
    
    # Step 3: Rename foreign key constraints for user_lemma
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user_lemma'::regclass
                AND contype = 'f'
                AND conname LIKE 'user_lemmas_%'
            ) LOOP
                EXECUTE 'ALTER TABLE user_lemma RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_lemmas_', 'user_lemma_');
            END LOOP;
        END $$;
    """))
    
    # Step 4: Rename foreign key constraints that reference user_lemmas (constraint names only, references auto-update)
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%user_lemmas%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_lemmas', 'user_lemma');
            END LOOP;
        END $$;
    """))
    
    # Step 5: Rename exercises to exercise
    op.rename_table('exercises', 'exercise')
    
    # Step 6: Rename indexes for exercise
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'exercise'
                AND indexname LIKE 'ix_exercises_%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_exercises_', 'ix_exercise_');
            END LOOP;
        END $$;
    """))
    
    # Step 7: Rename foreign key constraints for exercise
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercise'::regclass
                AND contype = 'f'
                AND conname LIKE 'exercises_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercise RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercises_', 'exercise_');
            END LOOP;
        END $$;
    """))
    
    # Step 8: Rename CHECK constraints for exercise
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercise'::regclass
                AND contype = 'c'
                AND conname LIKE 'exercises_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercise RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercises_', 'exercise_');
            END LOOP;
        END $$;
    """))
    
    # Step 9: Rename foreign key constraint names that reference exercises
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%exercises%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercises', 'exercise');
            END LOOP;
        END $$;
    """))
    
    # Step 10: Rename users to user (do this last as it's referenced by many tables)
    op.rename_table('users', 'user')
    
    # Step 11: Rename indexes for user
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'user'
                AND indexname LIKE 'ix_users_%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_users_', 'ix_user_');
            END LOOP;
        END $$;
    """))
    
    # Step 12: Rename foreign key constraints for user
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user'::regclass
                AND contype = 'f'
                AND conname LIKE 'users_%'
            ) LOOP
                EXECUTE 'ALTER TABLE "user" RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'users_', 'user_');
            END LOOP;
        END $$;
    """))
    
    # Step 13: Rename foreign key constraint names that reference users
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%users%'
                AND conname NOT LIKE '%user_lemma%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'users', 'user');
            END LOOP;
        END $$;
    """))


def downgrade() -> None:
    """
    Revert the changes: rename tables back to plural form.
    """
    
    # Step 1: Rename foreign key constraint names that reference user back to users
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%user%'
                AND conname NOT LIKE '%user_lemma%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user', 'users');
            END LOOP;
        END $$;
    """))
    
    # Step 2: Rename foreign key constraints for user back to users
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user'::regclass
                AND contype = 'f'
                AND conname LIKE 'user_%'
                AND conname NOT LIKE 'user_lemma_%'
            ) LOOP
                EXECUTE 'ALTER TABLE "user" RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_', 'users_');
            END LOOP;
        END $$;
    """))
    
    # Step 3: Rename indexes for user back to users
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'user'
                AND indexname LIKE 'ix_user_%'
                AND indexname NOT LIKE 'ix_user_lemma%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_user_', 'ix_users_');
            END LOOP;
        END $$;
    """))
    
    # Step 4: Rename user back to users
    op.rename_table('user', 'users')
    
    # Step 5: Rename foreign key constraint names that reference exercise back to exercises
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%exercise%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercise', 'exercises');
            END LOOP;
        END $$;
    """))
    
    # Step 6: Rename CHECK constraints for exercise back to exercises
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercise'::regclass
                AND contype = 'c'
                AND conname LIKE 'exercise_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercise RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercise_', 'exercises_');
            END LOOP;
        END $$;
    """))
    
    # Step 7: Rename foreign key constraints for exercise back to exercises
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'exercise'::regclass
                AND contype = 'f'
                AND conname LIKE 'exercise_%'
            ) LOOP
                EXECUTE 'ALTER TABLE exercise RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercise_', 'exercises_');
            END LOOP;
        END $$;
    """))
    
    # Step 8: Rename indexes for exercise back to exercises
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'exercise'
                AND indexname LIKE 'ix_exercise_%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_exercise_', 'ix_exercises_');
            END LOOP;
        END $$;
    """))
    
    # Step 9: Rename exercise back to exercises
    op.rename_table('exercise', 'exercises')
    
    # Step 10: Rename foreign key constraint names that reference user_lemma back to user_lemmas
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname, conrelid::regclass::text as table_name
                FROM pg_constraint
                WHERE contype = 'f'
                AND conname LIKE '%user_lemma%'
            ) LOOP
                EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name) || 
                        ' RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_lemma', 'user_lemmas');
            END LOOP;
        END $$;
    """))
    
    # Step 11: Rename foreign key constraints for user_lemma back to user_lemmas
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user_lemma'::regclass
                AND contype = 'f'
                AND conname LIKE 'user_lemma_%'
            ) LOOP
                EXECUTE 'ALTER TABLE user_lemma RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_lemma_', 'user_lemmas_');
            END LOOP;
        END $$;
    """))
    
    # Step 12: Rename indexes for user_lemma back to user_lemmas
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT indexname
                FROM pg_indexes
                WHERE tablename = 'user_lemma'
                AND indexname LIKE 'ix_user_lemma_%'
            ) LOOP
                EXECUTE 'ALTER INDEX ' || quote_ident(r.indexname) || 
                        ' RENAME TO ' || replace(r.indexname, 'ix_user_lemma_', 'ix_user_lemmas_');
            END LOOP;
        END $$;
    """))
    
    # Step 13: Rename user_lemma back to user_lemmas
    op.rename_table('user_lemma', 'user_lemmas')

