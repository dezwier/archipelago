"""Remove internal_name and rename tables to singular

Revision ID: 005_remove_internal_name_rename_tables
Revises: 004_insert_languages
Create Date: 2024-12-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '005_remove_internal_name'
down_revision = '004_insert_languages'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename topics table to topic
    op.rename_table('topics', 'topic')
    
    # Rename concepts table to concept
    op.rename_table('concepts', 'concept')
    
    # Update foreign key constraint name for concept.topic_id
    op.drop_constraint('concepts_topic_id_fkey', 'concept', type_='foreignkey')
    op.create_foreign_key('concept_topic_id_fkey', 'concept', 'topic', ['topic_id'], ['id'])
    
    # Update foreign key constraint for cards.concept_id
    op.drop_constraint('cards_concept_id_fkey', 'cards', type_='foreignkey')
    op.create_foreign_key('cards_concept_id_fkey', 'cards', 'concept', ['concept_id'], ['id'])
    
    # Remove internal_name column from concept table
    op.drop_column('concept', 'internal_name')
    
    # Update index name
    op.drop_index(op.f('ix_concepts_topic_id'), table_name='concept')
    op.create_index(op.f('ix_concept_topic_id'), 'concept', ['topic_id'], unique=False)


def downgrade() -> None:
    # Update foreign key constraint for cards.concept_id back
    op.drop_constraint('cards_concept_id_fkey', 'cards', type_='foreignkey')
    op.create_foreign_key('cards_concept_id_fkey', 'cards', 'concepts', ['concept_id'], ['id'])
    
    # Add internal_name column back (as nullable for safety)
    op.add_column('concept', sa.Column('internal_name', sa.String(), nullable=True))
    
    # Update index name back
    op.drop_index(op.f('ix_concept_topic_id'), table_name='concept')
    op.create_index(op.f('ix_concepts_topic_id'), 'concept', ['topic_id'], unique=False)
    
    # Update foreign key constraint name back
    op.drop_constraint('concept_topic_id_fkey', 'concept', type_='foreignkey')
    op.create_foreign_key('concepts_topic_id_fkey', 'concept', 'topics', ['topic_id'], ['id'])
    
    # Rename tables back
    op.rename_table('concept', 'concepts')
    op.rename_table('topic', 'topics')

