"""add dictionary tables and FK columns

Revision ID: 0004
Revises: 0003
Create Date: 2026-04-11

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- dictionary_entries ---
    op.create_table(
        "dictionary_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column("lemma", sa.String(255), nullable=False),
        sa.Column("display_form", sa.String(255), nullable=True),
        sa.Column("word_type", sa.String(64), nullable=False),
        sa.Column("phonetic", sa.String(255), nullable=True),
        sa.Column("frequency_rank", sa.Integer(), nullable=True),
        sa.Column("cefr_estimate", sa.String(2), nullable=True),
        sa.Column("senses", sa.JSON(), nullable=False),
        sa.Column("etymology", sa.Text(), nullable=True),
        sa.Column("synonyms", sa.JSON(), nullable=True),
        sa.Column(
            "source",
            sa.String(64),
            server_default="wiktionary",
            nullable=False,
        ),
        sa.Column("source_version", sa.String(32), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "language", "lemma", "word_type", name="uq_dictionary_lang_lemma_word_type"
        ),
    )
    op.create_index(
        "ix_dictionary_entries_lang_lemma",
        "dictionary_entries",
        ["language", "lemma"],
    )
    op.create_index(
        "ix_dictionary_entries_lang_freq",
        "dictionary_entries",
        ["language", "frequency_rank"],
    )
    op.create_index(
        "ix_dictionary_entries_lang_cefr",
        "dictionary_entries",
        ["language", "cefr_estimate"],
    )

    # --- dictionary_forms ---
    op.create_table(
        "dictionary_forms",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column("surface_form", sa.String(255), nullable=False),
        sa.Column("lemma", sa.String(255), nullable=False),
        sa.Column("word_type", sa.String(64), nullable=False),
        sa.Column("dictionary_entry_id", sa.Uuid(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["dictionary_entry_id"],
            ["dictionary_entries.id"],
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "language",
            "surface_form",
            "word_type",
            name="uq_dictionary_form_lang_surface_word_type",
        ),
    )
    op.create_index(
        "ix_dictionary_forms_lang_surface",
        "dictionary_forms",
        ["language", "surface_form"],
    )

    # --- add dictionary_entry_id FK to passage_vocabulary ---
    op.add_column(
        "passage_vocabulary",
        sa.Column("dictionary_entry_id", sa.Uuid(), nullable=True),
    )
    op.create_foreign_key(
        "fk_passage_vocabulary_dictionary_entry_id",
        "passage_vocabulary",
        "dictionary_entries",
        ["dictionary_entry_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # --- add dictionary_entry_id FK to vocabulary_items ---
    op.add_column(
        "vocabulary_items",
        sa.Column("dictionary_entry_id", sa.Uuid(), nullable=True),
    )
    op.create_foreign_key(
        "fk_vocabulary_items_dictionary_entry_id",
        "vocabulary_items",
        "dictionary_entries",
        ["dictionary_entry_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    # Drop FK columns from existing tables
    op.drop_constraint(
        "fk_vocabulary_items_dictionary_entry_id",
        "vocabulary_items",
        type_="foreignkey",
    )
    op.drop_column("vocabulary_items", "dictionary_entry_id")

    op.drop_constraint(
        "fk_passage_vocabulary_dictionary_entry_id",
        "passage_vocabulary",
        type_="foreignkey",
    )
    op.drop_column("passage_vocabulary", "dictionary_entry_id")

    # Drop dictionary tables (forms first due to FK dependency)
    op.drop_table("dictionary_forms")
    op.drop_table("dictionary_entries")
