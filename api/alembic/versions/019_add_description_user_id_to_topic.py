"""Add description and user_id fields to topic table

Revision ID: 019_add_description_user_id_to_topic
Revises: 018_case_insensitive_uq
Create Date: 2024-12-21 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '019_topic_desc_user_id'
down_revision = '018_case_insensitive_uq'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add description column (nullable)
    op.add_column('topic', sa.Column('description', sa.String(), nullable=True))
    
    # Add user_id column (nullable first)
    op.add_column('topic', sa.Column('user_id', sa.Integer(), nullable=True))
    
    # Set all existing records to user_id = 1
    connection = op.get_bind()
    connection.execute(
        sa.text("""
            UPDATE topic
            SET user_id = 1
            WHERE user_id IS NULL
        """)
    )
    
    # Make user_id NOT NULL
    op.alter_column('topic', 'user_id', nullable=False)
    
    # Add foreign key constraint
    op.create_foreign_key(
        'fk_topic_user_id',
        'topic',
        'users',
        ['user_id'],
        ['id']
    )
    
    # Add index for better query performance
    op.create_index(op.f('ix_topic_user_id'), 'topic', ['user_id'], unique=False)


def downgrade() -> None:
    # Remove index
    op.drop_index(op.f('ix_topic_user_id'), table_name='topic')
    
    # Remove foreign key constraint
    op.drop_constraint('fk_topic_user_id', 'topic', type_='foreignkey')
    
    # Remove columns
    op.drop_column('topic', 'user_id')
    op.drop_column('topic', 'description')
