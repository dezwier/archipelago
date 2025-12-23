"""Update lesson learning_language to FK and populate lessons for existing exercises

Revision ID: 036_update_lesson_learning_language_fk_and_populate
Revises: 035_add_lesson_id_to_exercise
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision = '036_lesson_fk_and_populate'
down_revision = '035_add_lesson_id_to_exercise'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    1. For existing exercises, create lesson records grouped by user and learning language
    2. Update exercises to point to their lesson
    3. Change learning_language from string to foreign key
    4. Make lesson_id non-nullable
    """
    
    # Step 1: Create lesson records for existing exercises
    # Group exercises by user_id and user's lang_learning
    # For each group, create a lesson with:
    #   - user_id
    #   - learning_language (from user.lang_learning)
    #   - kind = 'new'
    #   - start_time = min(exercise.start_time)
    #   - end_time = max(exercise.end_time)
    
    op.execute(text("""
        INSERT INTO lesson (user_id, learning_language, kind, start_time, end_time)
        SELECT DISTINCT
            u.id as user_id,
            LOWER(u.lang_learning) as learning_language,
            'new' as kind,
            MIN(e.start_time) as start_time,
            MAX(e.end_time) as end_time
        FROM exercise e
        INNER JOIN user_lemma ul ON e.user_lemma_id = ul.id
        INNER JOIN "user" u ON ul.user_id = u.id
        WHERE e.lesson_id IS NULL
          AND u.lang_learning IS NOT NULL
          AND u.lang_learning != ''
        GROUP BY u.id, LOWER(u.lang_learning)
    """))
    
    # Step 2: Update exercises to point to their lesson
    # Match exercises to lessons by user_id and learning_language
    op.execute(text("""
        UPDATE exercise e
        SET lesson_id = l.id
        FROM user_lemma ul
        INNER JOIN "user" u ON ul.user_id = u.id
        INNER JOIN lesson l ON l.user_id = u.id 
            AND LOWER(l.learning_language) = LOWER(u.lang_learning)
        WHERE e.user_lemma_id = ul.id
          AND e.lesson_id IS NULL
          AND u.lang_learning IS NOT NULL
          AND u.lang_learning != ''
    """))
    
    # Step 3: Drop the old learning_language column constraint and foreign key if any
    # (There shouldn't be a foreign key yet, but we'll handle it)
    
    # Step 4: Change learning_language column to reference languages.code
    # First, ensure all learning_language values exist in languages table
    # If not, we'll need to handle that - but for now, assume they do
    
    # Drop the CHECK constraint if it exists (from the original migration)
    op.execute(text("""
        ALTER TABLE lesson DROP CONSTRAINT IF EXISTS lesson_kind_check
    """))
    
    # Change learning_language to be a foreign key
    # We need to:
    # 1. Add a new column with the FK
    # 2. Copy data (ensuring it's lowercase and exists in languages)
    # 3. Drop old column
    # 4. Rename new column
    
    # Add temporary column
    op.add_column('lesson', sa.Column('learning_language_fk', sa.String(length=2), nullable=True))
    
    # Copy and normalize data (ensure lowercase and exists in languages)
    op.execute(text("""
        UPDATE lesson
        SET learning_language_fk = LOWER(learning_language)
        WHERE learning_language_fk IS NULL
          AND EXISTS (
              SELECT 1 FROM languages 
              WHERE LOWER(languages.code) = LOWER(lesson.learning_language)
          )
    """))
    
    # For any lessons that don't have a matching language, we'll set to a default or skip
    # For now, let's delete lessons that don't have a valid language code
    op.execute(text("""
        DELETE FROM lesson
        WHERE learning_language_fk IS NULL
    """))
    
    # Drop old column
    op.drop_column('lesson', 'learning_language')
    
    # Rename new column
    op.alter_column('lesson', 'learning_language_fk', new_column_name='learning_language', existing_type=sa.String(length=2), existing_nullable=False)
    
    # Add foreign key constraint
    op.create_foreign_key(
        'lesson_learning_language_fkey',
        'lesson',
        'languages',
        ['learning_language'],
        ['code']
    )
    
    # Re-add CHECK constraint for kind
    op.create_check_constraint(
        'lesson_kind_check',
        'lesson',
        text("kind IN ('new', 'learned', 'all')")
    )
    
    # Step 5: Make lesson_id non-nullable in exercise table
    # First, delete any exercises that don't have a lesson_id (shouldn't happen after step 2, but just in case)
    op.execute(text("""
        DELETE FROM exercise WHERE lesson_id IS NULL
    """))
    
    # Make lesson_id non-nullable
    op.alter_column('exercise', 'lesson_id', nullable=False)


def downgrade() -> None:
    """
    Revert the changes:
    1. Make lesson_id nullable
    2. Change learning_language back to string
    3. Remove lesson records (optional - we'll keep them but unlink exercises)
    """
    
    # Make lesson_id nullable
    op.alter_column('exercise', 'lesson_id', nullable=True)
    
    # Remove foreign key constraint
    op.drop_constraint('lesson_learning_language_fkey', 'lesson', type_='foreignkey')
    
    # Drop CHECK constraint
    op.drop_constraint('lesson_kind_check', 'lesson', type_='check')
    
    # Change learning_language back to string
    op.add_column('lesson', sa.Column('learning_language_str', sa.String(), nullable=True))
    
    # Copy data back
    op.execute(text("""
        UPDATE lesson
        SET learning_language_str = learning_language
    """))
    
    # Drop FK column
    op.drop_column('lesson', 'learning_language')
    
    # Rename back
    op.alter_column('lesson', 'learning_language_str', new_column_name='learning_language', existing_type=sa.String(), existing_nullable=False)
    
    # Re-add CHECK constraint
    op.create_check_constraint(
        'lesson_kind_check',
        'lesson',
        text("kind IN ('new', 'learned', 'all')")
    )
    
    # Unlink exercises from lessons (set lesson_id to NULL)
    op.execute(text("""
        UPDATE exercise SET lesson_id = NULL
    """))

