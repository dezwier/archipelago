"""Create concept_topic table and migrate data

Revision ID: 041_create_concept_topic_and_migrate
Revises: 040_create_user_topic_table
Create Date: 2024-12-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '041_create_concept_topic'
down_revision = '040_create_user_topic_table'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create concept_topic table, migrate data, and drop topic_id from concept table."""
    # Create concept_topic junction table
    op.create_table(
        'concept_topic',
        sa.Column('concept_id', sa.Integer(), nullable=False),
        sa.Column('topic_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['concept_id'], ['concept.id'], ),
        sa.ForeignKeyConstraint(['topic_id'], ['topic.id'], ),
        sa.PrimaryKeyConstraint('concept_id', 'topic_id')
    )
    
    # Migrate existing data from concept.topic_id to concept_topic
    op.execute("""
        INSERT INTO concept_topic (concept_id, topic_id)
        SELECT id, topic_id
        FROM concept
        WHERE topic_id IS NOT NULL
    """)
    
    # Drop the foreign key constraint first
    op.drop_constraint('concept_topic_id_fkey', 'concept', type_='foreignkey')
    
    # Drop topic_id column from concept table
    op.drop_column('concept', 'topic_id')


def downgrade() -> None:
    """Restore topic_id column in concept table and drop concept_topic table."""
    # Add topic_id column back to concept table
    op.add_column('concept', sa.Column('topic_id', sa.Integer(), nullable=True))
    
    # Migrate data back from concept_topic to concept.topic_id
    # Note: This will only restore the first topic for each concept
    op.execute("""
        UPDATE concept c
        SET topic_id = (
            SELECT ct.topic_id
            FROM concept_topic ct
            WHERE ct.concept_id = c.id
            LIMIT 1
        )
    """)
    
    # Add foreign key constraint back
    op.create_foreign_key('concept_topic_id_fkey', 'concept', 'topic', ['topic_id'], ['id'])
    
    # Drop concept_topic table
    op.drop_table('concept_topic')

