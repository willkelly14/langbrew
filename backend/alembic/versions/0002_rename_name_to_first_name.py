"""Rename users.name to users.first_name.

Revision ID: 0002
Revises: 0001
Create Date: 2026-04-08
"""

from alembic import op

# revision identifiers
revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("users", "name", new_column_name="first_name")


def downgrade() -> None:
    op.alter_column("users", "first_name", new_column_name="name")
