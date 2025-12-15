"""Enforce one lemma per language for concepts with topic_id

Revision ID: 024_enforce_one_lemma_per_language_for_topics
Revises: 023_add_image_url_to_concept
Create Date: 2024-12-25 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '024_lemma_one_per_lang_topic'
down_revision = '023_add_image_url_to_concept'
branch_labels = None
depends_on = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Step 1: Clean up existing data
    # For concepts with topic_id, keep only the latest lemma per (concept_id, language_code) combination
    # "Latest" is determined by created_at (or id if created_at is the same)
    connection.execute(
        sa.text("""
            DELETE FROM lemma
            WHERE id IN (
                SELECT l.id
                FROM (
                    SELECT l.id,
                           ROW_NUMBER() OVER (
                               PARTITION BY l.concept_id, l.language_code
                               ORDER BY l.created_at DESC, l.id DESC
                           ) as rn
                    FROM lemma l
                    INNER JOIN concept c ON l.concept_id = c.id
                    WHERE c.topic_id IS NOT NULL
                ) l
                WHERE l.rn > 1
            )
        """)
    )
    
    # Step 2: Create a function to check uniqueness for concepts with topic_id
    connection.execute(
        sa.text("""
            CREATE OR REPLACE FUNCTION check_lemma_uniqueness_for_topics()
            RETURNS TRIGGER AS $$
            BEGIN
                -- Check if the concept has a topic_id
                IF EXISTS (
                    SELECT 1 FROM concept WHERE id = NEW.concept_id AND topic_id IS NOT NULL
                ) THEN
                    -- Check if there's already another lemma with the same concept_id and language_code
                    IF EXISTS (
                        SELECT 1 FROM lemma
                        WHERE concept_id = NEW.concept_id
                        AND language_code = NEW.language_code
                        AND id != NEW.id
                    ) THEN
                        RAISE EXCEPTION 'Only one lemma per language is allowed for concepts with topic_id. Concept ID: %, Language: %', NEW.concept_id, NEW.language_code;
                    END IF;
                END IF;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        """)
    )
    
    # Step 3: Create trigger to enforce the constraint
    connection.execute(
        sa.text("""
            CREATE TRIGGER trigger_check_lemma_uniqueness_for_topics
            BEFORE INSERT OR UPDATE ON lemma
            FOR EACH ROW
            EXECUTE FUNCTION check_lemma_uniqueness_for_topics();
        """)
    )


def downgrade() -> None:
    connection = op.get_bind()
    
    # Drop the trigger
    connection.execute(
        sa.text("""
            DROP TRIGGER IF EXISTS trigger_check_lemma_uniqueness_for_topics ON lemma;
        """)
    )
    
    # Drop the function
    connection.execute(
        sa.text("""
            DROP FUNCTION IF EXISTS check_lemma_uniqueness_for_topics();
        """)
    )

