"""Rename card table to lemma

Revision ID: 020_rename_card_to_lemma
Revises: 019_topic_desc_user_id
Create Date: 2024-12-22 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '020_rename_card_to_lemma'
down_revision = '019_topic_desc_user_id'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Rename the unique index
    op.execute(
        sa.text("""
            DROP INDEX IF EXISTS uq_card_concept_language_term_ci;
        """)
    )
    
    # Step 2: Rename the table
    op.rename_table('card', 'lemma')
    
    # Step 3: Recreate the unique index with new name
    op.execute(
        sa.text("""
            CREATE UNIQUE INDEX uq_lemma_concept_language_term_ci 
            ON lemma (concept_id, language_code, LOWER(TRIM(term)));
        """)
    )
    
    # Step 4: Rename foreign key constraint in user_cards table
    # First, drop the old foreign key constraint
    op.execute(
        sa.text("""
            ALTER TABLE user_cards 
            DROP CONSTRAINT IF EXISTS user_cards_card_id_fkey;
        """)
    )
    
    # Step 5: Rename the column in user_cards table
    op.alter_column('user_cards', 'card_id', new_column_name='lemma_id', existing_type=sa.Integer(), existing_nullable=False)
    
    # Step 6: Recreate the foreign key constraint with new name
    op.create_foreign_key(
        'user_cards_lemma_id_fkey',
        'user_cards',
        'lemma',
        ['lemma_id'],
        ['id'],
        ondelete='CASCADE'
    )


def downgrade() -> None:
    # Step 1: Drop the unique index
    op.execute(
        sa.text("""
            DROP INDEX IF EXISTS uq_lemma_concept_language_term_ci;
        """)
    )
    
    # Step 2: Rename the table back
    op.rename_table('lemma', 'card')
    
    # Step 3: Recreate the unique index with old name
    op.execute(
        sa.text("""
            CREATE UNIQUE INDEX uq_card_concept_language_term_ci 
            ON card (concept_id, language_code, LOWER(TRIM(term)));
        """)
    )
    
    # Step 4: Drop the foreign key constraint
    op.execute(
        sa.text("""
            ALTER TABLE user_cards 
            DROP CONSTRAINT IF EXISTS user_cards_lemma_id_fkey;
        """)
    )
    
    # Step 5: Rename the column back
    op.alter_column('user_cards', 'lemma_id', new_column_name='card_id', existing_type=sa.Integer(), existing_nullable=False)
    
    # Step 6: Recreate the foreign key constraint with old name
    op.create_foreign_key(
        'user_cards_card_id_fkey',
        'user_cards',
        'card',
        ['card_id'],
        ['id'],
        ondelete='CASCADE'
    )





