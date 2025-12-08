"""Enforce card concept_id foreign key constraint and clean orphaned cards

Revision ID: 012_enforce_card_concept_fk
Revises: 011_update_cards_table_to_card
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '012_enforce_card_concept_fk'
down_revision = '011_update_cards_table_to_card'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Find and delete any orphaned cards (cards with concept_id that doesn't exist)
    # This ensures data integrity before we enforce the FK constraint
    op.execute(sa.text("""
        DELETE FROM card
        WHERE concept_id NOT IN (SELECT id FROM concept)
    """))
    
    # Step 2: Ensure concept_id is NOT NULL (should already be, but enforce it)
    op.alter_column('card', 'concept_id',
                   existing_type=sa.Integer(),
                   nullable=False)
    
    # Step 3: Drop existing FK constraint if it exists (to recreate with CASCADE)
    # First check if the constraint exists and drop it
    op.execute(sa.text("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conname = 'cards_concept_id_fkey'
            ) THEN
                ALTER TABLE card DROP CONSTRAINT cards_concept_id_fkey;
            END IF;
        END $$;
    """))
    
    # Step 4: Recreate FK constraint with CASCADE DELETE
    # This ensures that if a concept is deleted, all its cards are automatically deleted
    op.create_foreign_key(
        'card_concept_id_fkey',
        'card',
        'concept',
        ['concept_id'],
        ['id'],
        ondelete='CASCADE'  # Automatically delete cards when concept is deleted
    )


def downgrade() -> None:
    # Drop the CASCADE FK constraint
    op.drop_constraint('card_concept_id_fkey', 'card', type_='foreignkey')
    
    # Recreate the original FK constraint without CASCADE
    op.create_foreign_key(
        'cards_concept_id_fkey',
        'card',
        'concept',
        ['concept_id'],
        ['id']
    )

