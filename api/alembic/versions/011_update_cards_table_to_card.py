"""Update cards table to card with new schema

Revision ID: 011_update_cards_table_to_card
Revises: 010_update_concept_table_fields
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '011_update_cards_table_to_card'
down_revision = '010_update_concept_table_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Drop the unique constraint (it references the old column name)
    op.drop_constraint(
        'uq_card_concept_language_translation',
        'cards',
        type_='unique'
    )
    
    # Step 2: Rename columns in cards table
    op.alter_column('cards', 'translation', new_column_name='term', existing_type=sa.String(), existing_nullable=False)
    op.alter_column('cards', 'audio_path', new_column_name='audio_url', existing_type=sa.String(), existing_nullable=True)
    op.alter_column('cards', 'creation_time', new_column_name='created_at', existing_type=sa.DateTime(), existing_nullable=False)
    
    # Make description nullable (per new schema requirements)
    op.alter_column('cards', 'description', existing_type=sa.String(), nullable=True)
    
    # Step 3: Add new columns
    op.add_column('cards', sa.Column('article', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('plural_form', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('verb_type', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('auxiliary_verb', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('register', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('confidence_score', sa.Float(), nullable=True))
    op.add_column('cards', sa.Column('status', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('source', sa.Text(), nullable=True))
    op.add_column('cards', sa.Column('updated_at', sa.DateTime(), nullable=True))
    
    # Step 4: Update foreign key references in user_cards table before renaming
    # First, drop the foreign key constraint
    op.drop_constraint('user_cards_card_id_fkey', 'user_cards', type_='foreignkey')
    
    # Step 5: Rename the table from cards to card
    op.rename_table('cards', 'card')
    
    # Step 6: Recreate the foreign key constraint with new table name
    op.create_foreign_key(
        'user_cards_card_id_fkey',
        'user_cards',
        'card',
        ['card_id'],
        ['id']
    )
    
    # Step 7: Recreate the unique constraint with new column name
    op.create_unique_constraint(
        'uq_card_concept_language_term',
        'card',
        ['concept_id', 'language_code', 'term']
    )
    
    # Step 8: Recreate indexes with new table name
    # Note: When table is renamed, indexes may keep old names or be auto-renamed depending on DB
    # We'll explicitly drop and recreate to ensure consistent naming
    # Use raw SQL to drop indexes if they exist (to avoid errors if already renamed)
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_concept_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_cards_language_code"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_card_concept_id"))
    op.execute(sa.text("DROP INDEX IF EXISTS ix_card_language_code"))
    
    # Create indexes with new names
    op.create_index('ix_card_concept_id', 'card', ['concept_id'], unique=False)
    op.create_index('ix_card_language_code', 'card', ['language_code'], unique=False)


def downgrade() -> None:
    # Step 1: Drop the unique constraint
    op.drop_constraint(
        'uq_card_concept_language_term',
        'card',
        type_='unique'
    )
    
    # Step 2: Drop indexes (they will be recreated with old names after table rename)
    op.drop_index('ix_card_language_code', table_name='card')
    op.drop_index('ix_card_concept_id', table_name='card')
    
    # Step 3: Drop foreign key constraint
    op.drop_constraint('user_cards_card_id_fkey', 'user_cards', type_='foreignkey')
    
    # Step 4: Rename table back to cards
    op.rename_table('card', 'cards')
    
    # Step 5: Recreate foreign key constraint
    op.create_foreign_key(
        'user_cards_card_id_fkey',
        'user_cards',
        'cards',
        ['card_id'],
        ['id']
    )
    
    # Step 6: Remove new columns
    op.drop_column('cards', 'updated_at')
    op.drop_column('cards', 'source')
    op.drop_column('cards', 'status')
    op.drop_column('cards', 'confidence_score')
    op.drop_column('cards', 'register')
    op.drop_column('cards', 'auxiliary_verb')
    op.drop_column('cards', 'verb_type')
    op.drop_column('cards', 'plural_form')
    op.drop_column('cards', 'article')
    
    # Step 7: Rename columns back
    op.alter_column('cards', 'created_at', new_column_name='creation_time', existing_type=sa.DateTime(), existing_nullable=False)
    op.alter_column('cards', 'audio_url', new_column_name='audio_path', existing_type=sa.String(), existing_nullable=True)
    op.alter_column('cards', 'term', new_column_name='translation', existing_type=sa.String(), existing_nullable=False)
    
    # Make description NOT NULL again (reverting to original schema)
    op.alter_column('cards', 'description', existing_type=sa.String(), nullable=False)
    
    # Step 8: Recreate indexes
    op.create_index('ix_cards_language_code', 'cards', ['language_code'], unique=False)
    op.create_index('ix_cards_concept_id', 'cards', ['concept_id'], unique=False)
    
    # Step 9: Recreate unique constraint with old column name
    op.create_unique_constraint(
        'uq_card_concept_language_translation',
        'cards',
        ['concept_id', 'language_code', 'translation']
    )

