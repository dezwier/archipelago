"""Initial migration: create all tables

Revision ID: initial
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create topics table
    op.create_table(
        'topics',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create languages table
    op.create_table(
        'languages',
        sa.Column('code', sa.String(length=2), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('code')
    )
    
    # Create concepts table
    op.create_table(
        'concepts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('internal_name', sa.String(), nullable=False),
        sa.Column('image_path_1', sa.String(), nullable=True),
        sa.Column('image_path_2', sa.String(), nullable=True),
        sa.Column('image_path_3', sa.String(), nullable=True),
        sa.Column('image_path_4', sa.String(), nullable=True),
        sa.Column('topic_id', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['topic_id'], ['topics.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_concepts_topic_id'), 'concepts', ['topic_id'], unique=False)
    
    # Create cards table
    op.create_table(
        'cards',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('concept_id', sa.Integer(), nullable=False),
        sa.Column('language_code', sa.String(length=2), nullable=False),
        sa.Column('translation', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=False),
        sa.Column('ipa', sa.String(), nullable=True),
        sa.Column('audio_path', sa.String(), nullable=True),
        sa.Column('gender', sa.String(), nullable=True),
        sa.Column('notes', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['concept_id'], ['concepts.id'], ),
        sa.ForeignKeyConstraint(['language_code'], ['languages.code'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_cards_concept_id'), 'cards', ['concept_id'], unique=False)
    op.create_index(op.f('ix_cards_language_code'), 'cards', ['language_code'], unique=False)
    
    # Create users table
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('lang_native', sa.String(), nullable=False),
        sa.Column('lang_learning', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create user_cards table
    op.create_table(
        'user_cards',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('card_id', sa.Integer(), nullable=False),
        sa.Column('image_path', sa.String(), nullable=True),
        sa.Column('created_time', sa.DateTime(), nullable=False),
        sa.Column('last_success_time', sa.DateTime(), nullable=True),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('next_review_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['card_id'], ['cards.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_cards_user_id'), 'user_cards', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_cards_card_id'), 'user_cards', ['card_id'], unique=False)
    
    # Create user_practices table
    op.create_table(
        'user_practices',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('created_time', sa.DateTime(), nullable=False),
        sa.Column('success', sa.Boolean(), nullable=False),
        sa.Column('feedback', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_practices_user_id'), 'user_practices', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_user_practices_user_id'), table_name='user_practices')
    op.drop_table('user_practices')
    op.drop_index(op.f('ix_user_cards_card_id'), table_name='user_cards')
    op.drop_index(op.f('ix_user_cards_user_id'), table_name='user_cards')
    op.drop_table('user_cards')
    op.drop_table('users')
    op.drop_index(op.f('ix_cards_language_code'), table_name='cards')
    op.drop_index(op.f('ix_cards_concept_id'), table_name='cards')
    op.drop_table('cards')
    op.drop_index(op.f('ix_concepts_topic_id'), table_name='concepts')
    op.drop_table('concepts')
    op.drop_table('languages')
    op.drop_table('topics')

