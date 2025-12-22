"""Revise practice table schema and rename to exercises

Revision ID: 031_revise_practice_table
Revises: 030_rename_card_to_user_lemma
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '031_revise_practice_table'
down_revision = '030_rename_card_to_user_lemma'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Revise practices table and rename to exercises:
    - Drop user_id column and foreign key
    - Drop created_time column
    - Add exercise_type column (string)
    - Convert result from int to string enum ('success', 'hint', 'fail')
    - Add start_time and end_time columns (datetime)
    - Rename table from practices to exercises
    """
    
    # Step 1: Drop foreign key constraint for user_id
    op.drop_constraint('practices_user_id_fkey', 'practices', type_='foreignkey')
    
    # Step 2: Drop index on user_id
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_user_id"))
    
    # Step 3: Drop user_id column
    op.drop_column('practices', 'user_id')
    
    # Step 4: Drop created_time column
    op.drop_column('practices', 'created_time')
    
    # Step 5: Add new columns as nullable initially
    op.add_column('practices', sa.Column('exercise_type', sa.String(), nullable=True))
    op.add_column('practices', sa.Column('start_time', sa.DateTime(), nullable=True))
    op.add_column('practices', sa.Column('end_time', sa.DateTime(), nullable=True))
    
    # Step 6: Convert result column from int to string
    # First, add a temporary column for the string result
    op.add_column('practices', sa.Column('result_str', sa.String(), nullable=True))
    
    # Step 7: Migrate existing data (if any)
    # Map int result to string: 1 -> 'success', 0 -> 'fail', others -> 'fail'
    # Since we don't have a clear mapping, we'll default to 'fail' for existing data
    op.execute(sa.text("""
        UPDATE practices 
        SET result_str = CASE 
            WHEN result = 1 THEN 'success'
            WHEN result = 0 THEN 'fail'
            ELSE 'fail'
        END
    """))
    
    # Step 8: Drop old result column
    op.drop_column('practices', 'result')
    
    # Step 9: Rename result_str to result
    op.alter_column('practices', 'result_str', new_column_name='result', existing_type=sa.String(), existing_nullable=True)
    
    # Step 10: Add CHECK constraint for result enum values
    op.create_check_constraint(
        'practices_result_check',
        'practices',
        sa.text("result IN ('success', 'hint', 'fail')")
    )
    
    # Step 11: Delete existing practices since we can't map them to new schema
    # (exercise_type, start_time, end_time are required but we don't have this data)
    op.execute(sa.text("DELETE FROM practices"))
    
    # Step 12: Make all new columns non-nullable
    op.alter_column('practices', 'exercise_type', nullable=False)
    op.alter_column('practices', 'result', nullable=False)
    op.alter_column('practices', 'start_time', nullable=False)
    op.alter_column('practices', 'end_time', nullable=False)
    
    # Step 13: Rename table from practices to exercises
    op.rename_table('practices', 'exercises')
    
    # Step 14: Rename foreign key constraint
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
    
    # Step 15: Rename indexes
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_user_lemma_id"))
    op.create_index(op.f('ix_exercises_user_lemma_id'), 'exercises', ['user_lemma_id'], unique=False)
    
    # Step 16: Rename CHECK constraint
    op.execute(sa.text("ALTER TABLE exercises RENAME CONSTRAINT practices_result_check TO exercises_result_check"))


def downgrade() -> None:
    """
    Revert the changes: rename exercises back to practices, restore user_id, created_time, and convert result back to int.
    """
    
    # Step 1: Rename table from exercises back to practices
    op.rename_table('exercises', 'practices')
    
    # Step 2: Rename foreign key constraints back
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'practices'::regclass
                AND contype = 'f'
                AND conname LIKE 'exercises_%'
            ) LOOP
                EXECUTE 'ALTER TABLE practices RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'exercises_', 'practices_');
            END LOOP;
        END $$;
    """))
    
    # Step 3: Rename indexes back
    op.execute(sa.text("DROP INDEX IF EXISTS ix_exercises_user_lemma_id"))
    op.create_index(op.f('ix_practices_user_lemma_id'), 'practices', ['user_lemma_id'], unique=False)
    
    # Step 4: Rename CHECK constraint back
    op.execute(sa.text("ALTER TABLE practices RENAME CONSTRAINT exercises_result_check TO practices_result_check"))
    
    # Step 5: Make columns nullable for downgrade
    op.alter_column('practices', 'exercise_type', nullable=True)
    op.alter_column('practices', 'start_time', nullable=True)
    op.alter_column('practices', 'end_time', nullable=True)
    
    # Step 6: Drop CHECK constraint
    op.drop_constraint('practices_result_check', 'practices', type_='check')
    
    # Step 7: Convert result from string to int
    # Add temporary int column
    op.add_column('practices', sa.Column('result_int', sa.Integer(), nullable=True))
    
    # Step 8: Migrate data: 'success' -> 1, 'hint' -> 0, 'fail' -> 0
    op.execute(sa.text("""
        UPDATE practices 
        SET result_int = CASE 
            WHEN result = 'success' THEN 1
            WHEN result = 'hint' THEN 0
            WHEN result = 'fail' THEN 0
            ELSE 0
        END
    """))
    
    # Step 9: Drop string result column
    op.drop_column('practices', 'result')
    
    # Step 10: Rename result_int to result
    op.alter_column('practices', 'result_int', new_column_name='result', existing_type=sa.Integer(), existing_nullable=True)
    
    # Step 11: Make result non-nullable with default
    op.alter_column('practices', 'result', nullable=False, server_default='0')
    
    # Step 12: Add back user_id column
    op.add_column('practices', sa.Column('user_id', sa.Integer(), nullable=True))
    
    # Step 13: Add back created_time column
    op.add_column('practices', sa.Column('created_time', sa.DateTime(), nullable=True))
    
    # Step 14: Create foreign key constraint for user_id
    op.create_foreign_key(
        'practices_user_id_fkey',
        'practices',
        'users',
        ['user_id'],
        ['id']
    )
    
    # Step 15: Create index on user_id
    op.create_index(op.f('ix_practices_user_id'), 'practices', ['user_id'], unique=False)
    
    # Step 16: Drop new columns
    op.drop_column('practices', 'exercise_type')
    op.drop_column('practices', 'start_time')
    op.drop_column('practices', 'end_time')

