"""Rename cards table to user_lemmas and update foreign keys

Revision ID: 030_rename_card_to_user_lemma
Revises: 029_rename_tables
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '030_rename_card_to_user_lemma'
down_revision = '029_rename_tables'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Rename cards table to user_lemmas.
    Update foreign key in practices table: card_id -> user_lemma_id
    """
    
    # ===== PRACTICES TABLE =====
    # Step 1: Drop the foreign key constraint for card_id
    op.drop_constraint('practices_card_id_fkey', 'practices', type_='foreignkey')
    
    # Step 2: Rename card_id column to user_lemma_id
    op.alter_column('practices', 'card_id', new_column_name='user_lemma_id', existing_type=sa.Integer(), existing_nullable=False)
    
    # Step 3: Drop the old index
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_card_id"))
    
    # Step 4: Create new index for user_lemma_id
    op.create_index(op.f('ix_practices_user_lemma_id'), 'practices', ['user_lemma_id'], unique=False)
    
    # ===== CARDS TABLE =====
    # Step 5: Rename cards table to user_lemmas
    op.rename_table('cards', 'user_lemmas')
    
    # Step 6: Rename indexes
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_user_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_lemma_id"))
    op.create_index(op.f('ix_user_lemmas_user_id'), 'user_lemmas', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_lemmas_lemma_id'), 'user_lemmas', ['lemma_id'], unique=False)
    
    # Step 7: Rename foreign key constraints
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            -- Rename foreign key constraints
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user_lemmas'::regclass
                AND contype = 'f'
            ) LOOP
                IF r.conname LIKE 'cards_%' THEN
                    EXECUTE 'ALTER TABLE user_lemmas RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                            ' TO ' || replace(r.conname, 'cards_', 'user_lemmas_');
                END IF;
            END LOOP;
        END $$;
    """))
    
    # Step 8: Create foreign key constraint for user_lemma_id in practices table
    op.create_foreign_key(
        'practices_user_lemma_id_fkey',
        'practices',
        'user_lemmas',
        ['user_lemma_id'],
        ['id']
    )


def downgrade() -> None:
    """
    Revert the changes: rename user_lemmas back to cards and user_lemma_id back to card_id.
    """
    
    # ===== PRACTICES TABLE =====
    # Step 1: Drop the foreign key constraint for user_lemma_id
    op.drop_constraint('practices_user_lemma_id_fkey', 'practices', type_='foreignkey')
    
    # Step 2: Drop the index
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_user_lemma_id"))
    
    # Step 3: Rename user_lemma_id column back to card_id
    op.alter_column('practices', 'user_lemma_id', new_column_name='card_id', existing_type=sa.Integer(), existing_nullable=False)
    
    # Step 4: Create index for card_id
    op.create_index(op.f('ix_practices_card_id'), 'practices', ['card_id'], unique=False)
    
    # Step 5: Create foreign key constraint for card_id
    op.create_foreign_key(
        'practices_card_id_fkey',
        'practices',
        'cards',
        ['card_id'],
        ['id']
    )
    
    # ===== USER_LEMMAS TABLE =====
    # Step 6: Rename foreign key constraints back
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'user_lemmas'::regclass
                AND contype = 'f'
                AND conname LIKE 'user_lemmas_%'
            ) LOOP
                EXECUTE 'ALTER TABLE user_lemmas RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_lemmas_', 'cards_');
            END LOOP;
        END $$;
    """))
    
    # Step 7: Rename indexes back
    op.execute(sa.text("DROP INDEX IF EXISTS ix_user_lemmas_lemma_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_user_lemmas_user_id"))
    op.create_index(op.f('ix_cards_user_id'), 'cards', ['user_id'], unique=False)
    op.create_index(op.f('ix_cards_lemma_id'), 'cards', ['lemma_id'], unique=False)
    
    # Step 8: Rename user_lemmas table back to cards
    op.rename_table('user_lemmas', 'cards')

