"""Rename gmail column to email in users table

Revision ID: 003_rename_gmail_to_email
Revises: 002_add_user_auth_fields
Create Date: 2024-01-03 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '003_rename_gmail_to_email'
down_revision = '002_add_user_auth_fields'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop the old index first
    op.drop_index(op.f('ix_users_gmail'), table_name='users')
    
    # Rename the column from gmail to email using raw SQL
    op.execute('ALTER TABLE users RENAME COLUMN gmail TO email')
    
    # Create the new index with the new column name
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)


def downgrade() -> None:
    # Drop the email index
    op.drop_index(op.f('ix_users_email'), table_name='users')
    
    # Rename back from email to gmail using raw SQL
    op.execute('ALTER TABLE users RENAME COLUMN email TO gmail')
    
    # Recreate the gmail index
    op.create_index(op.f('ix_users_gmail'), 'users', ['gmail'], unique=True)

