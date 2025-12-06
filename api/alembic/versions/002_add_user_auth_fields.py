"""Add username, gmail, and password fields to users table

Revision ID: 002_add_user_auth_fields
Revises: initial
Create Date: 2024-01-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '002_add_user_auth_fields'
down_revision = 'initial'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add new fields to users table (nullable first to handle existing data)
    op.add_column('users', sa.Column('username', sa.String(), nullable=True))
    op.add_column('users', sa.Column('gmail', sa.String(), nullable=True))
    op.add_column('users', sa.Column('password', sa.String(), nullable=True))
    
    # If there are existing users, you'll need to populate these fields before making them non-nullable
    # For now, we'll make them nullable to allow the migration to succeed
    # You can update existing users and then make these fields non-nullable in a subsequent migration
    
    # Create unique indexes for username and gmail (nullable fields can still have unique indexes)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)
    op.create_index(op.f('ix_users_gmail'), 'users', ['gmail'], unique=True)


def downgrade() -> None:
    # Drop indexes
    op.drop_index(op.f('ix_users_gmail'), table_name='users')
    op.drop_index(op.f('ix_users_username'), table_name='users')
    
    # Drop columns
    op.drop_column('users', 'password')
    op.drop_column('users', 'gmail')
    op.drop_column('users', 'username')

