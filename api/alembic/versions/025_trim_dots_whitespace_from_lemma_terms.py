"""Trim dots and whitespace from lemma terms

Revision ID: 025_trim_lemma_terms
Revises: 024_lemma_one_per_lang_topic
Create Date: 2024-12-26 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '025_trim_lemma_terms'
down_revision = '024_lemma_one_per_lang_topic'
branch_labels = None
depends_on = None


def upgrade() -> None:
    connection = op.get_bind()
    
    # Create a SQL function to normalize terms (trim dots and whitespace)
    connection.execute(
        sa.text("""
            CREATE OR REPLACE FUNCTION normalize_lemma_term(input_term TEXT)
            RETURNS TEXT AS $$
            DECLARE
                normalized TEXT;
            BEGIN
                IF input_term IS NULL OR input_term = '' THEN
                    RETURN input_term;
                END IF;
                
                -- Strip leading and trailing whitespace first
                normalized := TRIM(input_term);
                
                -- Strip leading dots
                WHILE normalized LIKE '.%' LOOP
                    normalized := SUBSTRING(normalized FROM 2);
                END LOOP;
                
                -- Strip trailing dots
                WHILE normalized LIKE '%.' LOOP
                    normalized := SUBSTRING(normalized FROM 1 FOR LENGTH(normalized) - 1);
                END LOOP;
                
                -- Strip any remaining leading/trailing whitespace
                normalized := TRIM(normalized);
                
                RETURN normalized;
            END;
            $$ LANGUAGE plpgsql;
        """)
    )
    
    # Step 1: Update all lemmas, normalizing their terms
    # Handle duplicates by keeping the one with the lowest ID
    connection.execute(
        sa.text("""
            -- First, identify and remove duplicates that would be created after normalization
            -- Keep the lemma with the lowest ID for each (concept_id, language_code, normalized_term) combination
            DELETE FROM lemma
            WHERE id IN (
                SELECT l2.id
                FROM lemma l1
                INNER JOIN lemma l2 ON (
                    l1.concept_id = l2.concept_id
                    AND l1.language_code = l2.language_code
                    AND LOWER(normalize_lemma_term(l1.term)) = LOWER(normalize_lemma_term(l2.term))
                    AND l1.id < l2.id
                )
            );
        """)
    )
    
    # Step 2: Update all remaining lemmas with normalized terms
    connection.execute(
        sa.text("""
            UPDATE lemma
            SET term = normalize_lemma_term(term)
            WHERE term != normalize_lemma_term(term);
        """)
    )
    
    # Drop the temporary function
    connection.execute(
        sa.text("DROP FUNCTION IF EXISTS normalize_lemma_term(TEXT);")
    )


def downgrade() -> None:
    # This migration cannot be fully reversed as we don't know the original
    # leading/trailing dots and whitespace that were removed.
    # However, we can note that the data has been normalized.
    pass

