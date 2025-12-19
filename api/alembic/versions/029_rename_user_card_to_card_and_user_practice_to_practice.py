"""Rename user_cards to cards and user_practices to practices, update fields

Revision ID: 029_rename_tables
Revises: 028_cleanup_images
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '029_rename_tables'
down_revision = '028_cleanup_images'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Rename user_cards to cards and user_practices to practices.
    Update fields:
    - cards: remove image_path and status, add leitner_bin (int)
    - practices: remove success and feedback, add card_id (fk) and result (int)
    """
    
    # ===== CARDS TABLE =====
    # Step 1: Rename user_cards table to cards
    op.rename_table('user_cards', 'cards')
    
    # Step 2: Drop old columns from cards
    op.drop_column('cards', 'image_path')
    op.drop_column('cards', 'status')
    
    # Step 3: Add leitner_bin column (int, default 0)
    op.add_column('cards', sa.Column('leitner_bin', sa.Integer(), nullable=False, server_default='0'))
    
    # Step 4: Rename indexes
    op.execute(sa.text("DROP INDEX IF EXISTS ix_user_cards_user_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_user_cards_lemma_id"))
    op.create_index(op.f('ix_cards_user_id'), 'cards', ['user_id'], unique=False)
    op.create_index(op.f('ix_cards_lemma_id'), 'cards', ['lemma_id'], unique=False)
    
    # Step 5: Rename foreign key constraints
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            -- Rename foreign key constraints
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'cards'::regclass
                AND contype = 'f'
            ) LOOP
                IF r.conname LIKE 'user_cards_%' THEN
                    EXECUTE 'ALTER TABLE cards RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                            ' TO ' || replace(r.conname, 'user_cards_', 'cards_');
                END IF;
            END LOOP;
        END $$;
    """))
    
    # ===== PRACTICES TABLE =====
    # Step 6: Rename user_practices table to practices
    op.rename_table('user_practices', 'practices')
    
    # Step 7: Drop old columns from practices
    op.drop_column('practices', 'success')
    op.drop_column('practices', 'feedback')
    
    # Step 8: Add card_id (fk) and result (int) columns
    # First add as nullable to handle existing data
    op.add_column('practices', sa.Column('card_id', sa.Integer(), nullable=True))
    op.add_column('practices', sa.Column('result', sa.Integer(), nullable=True, server_default='0'))
    
    # Step 8a: Delete existing practices since they can't be mapped to cards
    # (card_id is required but we don't have a way to map old practices to cards)
    op.execute(sa.text("DELETE FROM practices"))
    
    # Step 8b: Now make card_id and result non-nullable
    op.alter_column('practices', 'card_id', nullable=False)
    op.alter_column('practices', 'result', nullable=False, server_default=None)
    
    # Step 9: Create foreign key constraint for card_id
    op.create_foreign_key(
        'practices_card_id_fkey',
        'practices',
        'cards',
        ['card_id'],
        ['id']
    )
    
    # Step 10: Rename indexes
    op.execute(sa.text("DROP INDEX IF EXISTS ix_user_practices_user_id"))
    op.create_index(op.f('ix_practices_user_id'), 'practices', ['user_id'], unique=False)
    op.create_index(op.f('ix_practices_card_id'), 'practices', ['card_id'], unique=False)
    
    # Step 11: Rename foreign key constraints for practices
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            -- Rename foreign key constraints
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'practices'::regclass
                AND contype = 'f'
                AND conname LIKE 'user_practices_%'
            ) LOOP
                EXECUTE 'ALTER TABLE practices RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'user_practices_', 'practices_');
            END LOOP;
        END $$;
    """))


def downgrade() -> None:
    """
    Revert the changes: rename cards back to user_cards and practices back to user_practices.
    Restore old columns and remove new ones.
    """
    
    # ===== PRACTICES TABLE =====
    # Step 1: Drop new columns from practices
    op.drop_constraint('practices_card_id_fkey', 'practices', type_='foreignkey')
    op.drop_column('practices', 'result')
    op.drop_column('practices', 'card_id')
    
    # Step 2: Add back old columns
    op.add_column('practices', sa.Column('success', sa.Boolean(), nullable=False))
    op.add_column('practices', sa.Column('feedback', sa.Integer(), nullable=True))
    
    # Step 3: Rename indexes back
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_card_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_practices_user_id"))
    op.create_index(op.f('ix_user_practices_user_id'), 'user_practices', ['user_id'], unique=False)
    
    # Step 4: Rename foreign key constraints back
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
                AND conname LIKE 'practices_%'
            ) LOOP
                EXECUTE 'ALTER TABLE practices RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'practices_', 'user_practices_');
            END LOOP;
        END $$;
    """))
    
    # Step 5: Rename practices table back to user_practices
    op.rename_table('practices', 'user_practices')
    
    # ===== CARDS TABLE =====
    # Step 6: Drop leitner_bin column
    op.drop_column('cards', 'leitner_bin')
    
    # Step 7: Add back old columns
    op.add_column('cards', sa.Column('image_path', sa.String(), nullable=True))
    op.add_column('cards', sa.Column('status', sa.String(), nullable=False, server_default='new'))
    
    # Step 8: Rename indexes back
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_lemma_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_user_id"))
    op.create_index(op.f('ix_user_cards_user_id'), 'user_cards', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_cards_lemma_id'), 'user_cards', ['lemma_id'], unique=False)
    
    # Step 9: Rename foreign key constraints back
    op.execute(sa.text("""
        DO $$
        DECLARE
            r RECORD;
        BEGIN
            FOR r IN (
                SELECT conname
                FROM pg_constraint
                WHERE conrelid = 'cards'::regclass
                AND contype = 'f'
                AND conname LIKE 'cards_%'
            ) LOOP
                EXECUTE 'ALTER TABLE cards RENAME CONSTRAINT ' || quote_ident(r.conname) || 
                        ' TO ' || replace(r.conname, 'cards_', 'user_cards_');
            END LOOP;
        END $$;
    """))
    
    # Step 10: Rename cards table back to user_cards
    op.rename_table('cards', 'user_cards')

