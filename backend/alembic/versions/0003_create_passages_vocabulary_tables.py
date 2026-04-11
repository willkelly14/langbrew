"""create passages vocabulary and user_streaks tables

Revision ID: 0003
Revises: 0002
Create Date: 2026-04-10

"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM as pgEnum

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Pre-create enum types if they don't already exist.
    # (They may have been created by earlier schema tooling.)
    conn = op.get_bind()
    for enum_name, values in [
        ("cefrlevel", ("A1", "A2", "B1", "B2", "C1")),
        ("passagestyle", ("article", "dialogue", "story", "letter")),
        ("passagelength", ("short", "medium", "long")),
        ("vocabularytype", ("word", "phrase", "sentence")),
        ("vocabularystatus", ("new", "learning", "known", "mastered")),
        ("sourcetype", ("passage", "book_chapter", "conversation")),
        ("studymode", ("daily", "hardest", "new", "ahead", "random")),
        ("cardtypefilter", ("all", "words", "phrases", "sentences")),
    ]:
        exists = conn.execute(
            sa.text("SELECT 1 FROM pg_type WHERE typname = :n"),
            {"n": enum_name},
        ).scalar()
        if not exists:
            vals = ", ".join(f"'{v}'" for v in values)
            conn.execute(sa.text(f"CREATE TYPE {enum_name} AS ENUM ({vals})"))

    # --- passages ---
    op.create_table(
        "passages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("user_language_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(512), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column(
            "cefr_level",
            pgEnum("A1", "A2", "B1", "B2", "C1", name="cefrlevel", create_type=False),
            nullable=False,
        ),
        sa.Column("topic", sa.String(255), nullable=False),
        sa.Column("word_count", sa.Integer(), nullable=False),
        sa.Column("estimated_minutes", sa.Integer(), nullable=False),
        sa.Column("known_word_percentage", sa.Float(), nullable=True),
        sa.Column(
            "is_generated",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column("source_book_id", sa.Uuid(), nullable=True),
        sa.Column("source_chapter_number", sa.Integer(), nullable=True),
        sa.Column(
            "style",
            pgEnum(
                "article",
                "dialogue",
                "story",
                "letter",
                name="passagestyle",
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column(
            "length",
            pgEnum("short", "medium", "long", name="passagelength", create_type=False),
            nullable=True,
        ),
        sa.Column(
            "reading_progress",
            sa.Float(),
            server_default="0.0",
            nullable=False,
        ),
        sa.Column("bookmark_position", sa.Integer(), nullable=True),
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["user_language_id"], ["user_languages.id"], ondelete="CASCADE"
        ),
    )
    op.create_index("ix_passages_user_language", "passages", ["user_id", "language"])
    op.create_index("ix_passages_user_created", "passages", ["user_id", "created_at"])

    # --- vocabulary_items ---
    op.create_table(
        "vocabulary_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("user_language_id", sa.Uuid(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column(
            "type",
            pgEnum(
                "word", "phrase", "sentence",
                name="vocabularytype", create_type=False,
            ),
            server_default="word",
            nullable=False,
        ),
        sa.Column("text", sa.String(512), nullable=False),
        sa.Column("translation", sa.String(512), nullable=False),
        sa.Column("phonetic", sa.String(255), nullable=True),
        sa.Column("word_type", sa.String(64), nullable=True),
        sa.Column("definitions", sa.JSON(), nullable=True),
        sa.Column("example_sentence", sa.Text(), nullable=True),
        sa.Column(
            "status",
            pgEnum(
                "new", "learning", "known", "mastered",
                name="vocabularystatus", create_type=False,
            ),
            server_default="new",
            nullable=False,
        ),
        sa.Column("ease_factor", sa.Float(), server_default="2.5", nullable=False),
        sa.Column("interval", sa.Integer(), server_default="0", nullable=False),
        sa.Column("repetitions", sa.Integer(), server_default="0", nullable=False),
        sa.Column("next_review_date", sa.Date(), nullable=True),
        sa.Column("times_reviewed", sa.Integer(), server_default="0", nullable=False),
        sa.Column("times_correct", sa.Integer(), server_default="0", nullable=False),
        sa.Column("last_reviewed_at", sa.DateTime(), nullable=True),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["user_language_id"], ["user_languages.id"], ondelete="CASCADE"
        ),
        sa.UniqueConstraint(
            "user_id", "language", "text", name="uq_vocabulary_user_lang_text"
        ),
    )
    op.create_index(
        "ix_vocabulary_items_user_lang_review",
        "vocabulary_items",
        ["user_id", "language", "next_review_date"],
    )
    op.create_index(
        "ix_vocabulary_items_user_lang_status",
        "vocabulary_items",
        ["user_id", "language", "status"],
    )

    # --- passage_vocabulary ---
    op.create_table(
        "passage_vocabulary",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("passage_id", sa.Uuid(), nullable=False),
        sa.Column("vocabulary_item_id", sa.Uuid(), nullable=True),
        sa.Column("word", sa.String(255), nullable=False),
        sa.Column("start_index", sa.Integer(), nullable=False),
        sa.Column("end_index", sa.Integer(), nullable=False),
        sa.Column(
            "is_highlighted",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column("definition", sa.Text(), nullable=True),
        sa.Column("translation", sa.String(512), nullable=True),
        sa.Column("phonetic", sa.String(255), nullable=True),
        sa.Column("word_type", sa.String(64), nullable=True),
        sa.Column("example_sentence", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["passage_id"], ["passages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["vocabulary_item_id"],
            ["vocabulary_items.id"],
            ondelete="SET NULL",
        ),
    )
    op.create_index(
        "ix_passage_vocabulary_passage_id",
        "passage_vocabulary",
        ["passage_id"],
    )
    op.create_index(
        "ix_passage_vocabulary_vocab_id",
        "passage_vocabulary",
        ["vocabulary_item_id"],
    )

    # --- vocabulary_encounters ---
    op.create_table(
        "vocabulary_encounters",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("vocabulary_item_id", sa.Uuid(), nullable=False),
        sa.Column(
            "source_type",
            pgEnum(
                "passage",
                "book_chapter",
                "conversation",
                name="sourcetype",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column("source_id", sa.Uuid(), nullable=False),
        sa.Column("context_sentence", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["vocabulary_item_id"],
            ["vocabulary_items.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_vocabulary_encounters_item_id",
        "vocabulary_encounters",
        ["vocabulary_item_id"],
    )
    op.create_index(
        "ix_vocabulary_encounters_source",
        "vocabulary_encounters",
        ["source_type", "source_id"],
    )

    # --- user_streaks ---
    op.create_table(
        "user_streaks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column(
            "minutes_studied",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "passages_read",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "cards_reviewed",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "chats_completed",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "words_learned",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id", "date", "language", name="uq_user_date_language"
        ),
    )


def downgrade() -> None:
    op.drop_table("user_streaks")
    op.drop_table("vocabulary_encounters")
    op.drop_table("passage_vocabulary")
    op.drop_table("vocabulary_items")
    op.drop_table("passages")

    # Drop enum types created in this migration
    op.execute("DROP TYPE IF EXISTS sourcetype")
    op.execute("DROP TYPE IF EXISTS vocabularystatus")
    op.execute("DROP TYPE IF EXISTS vocabularytype")
    op.execute("DROP TYPE IF EXISTS passagelength")
    op.execute("DROP TYPE IF EXISTS passagestyle")
