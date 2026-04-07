"""create user settings language device usage tables

Revision ID: 0001
Revises:
Create Date: 2026-04-07

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- users ---
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("supabase_uid", sa.String(255), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("name", sa.String(255), server_default="", nullable=False),
        sa.Column("avatar_url", sa.String(2048), nullable=True),
        sa.Column(
            "native_language",
            sa.String(10),
            server_default="en",
            nullable=False,
        ),
        sa.Column(
            "subscription_tier",
            sa.Enum("free", "fluency", name="subscriptiontier"),
            server_default="free",
            nullable=False,
        ),
        sa.Column("subscription_expires_at", sa.DateTime(), nullable=True),
        sa.Column("app_store_transaction_id", sa.String(255), nullable=True),
        sa.Column(
            "daily_goal_minutes",
            sa.Integer(),
            server_default="10",
            nullable=False,
        ),
        sa.Column(
            "new_words_per_day",
            sa.Integer(),
            server_default="10",
            nullable=False,
        ),
        sa.Column(
            "auto_adjust_difficulty",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "timezone",
            sa.String(64),
            server_default="UTC",
            nullable=False,
        ),
        sa.Column(
            "current_streak",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "onboarding_completed",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column(
            "onboarding_step",
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
        sa.UniqueConstraint("supabase_uid"),
    )
    op.create_index("ix_users_supabase_uid", "users", ["supabase_uid"])

    # --- user_settings ---
    op.create_table(
        "user_settings",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        # Reading
        sa.Column(
            "reading_theme",
            sa.Enum("light", "sepia", "dark", name="readingtheme"),
            server_default="light",
            nullable=False,
        ),
        sa.Column(
            "reading_font",
            sa.Enum("serif", "sans", name="readingfont"),
            server_default="serif",
            nullable=False,
        ),
        sa.Column(
            "font_size", sa.Integer(), server_default="16", nullable=False
        ),
        sa.Column(
            "line_spacing",
            sa.Enum("compact", "normal", "relaxed", name="linespacing"),
            server_default="normal",
            nullable=False,
        ),
        sa.Column(
            "vocabulary_highlights",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "auto_play_audio",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column(
            "highlight_following",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column("preferred_voice_id", sa.String(255), nullable=True),
        sa.Column(
            "voice_speed", sa.Float(), server_default="1.0", nullable=False
        ),
        # Talk
        sa.Column(
            "talk_voice_style",
            sa.String(64),
            server_default="natural",
            nullable=False,
        ),
        sa.Column(
            "talk_correction_style",
            sa.String(64),
            server_default="gentle",
            nullable=False,
        ),
        sa.Column(
            "show_transcript",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "auto_save_words",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "session_length_minutes",
            sa.Integer(),
            server_default="5",
            nullable=False,
        ),
        # Flashcard
        sa.Column(
            "reviews_per_session",
            sa.Integer(),
            server_default="20",
            nullable=False,
        ),
        sa.Column(
            "show_example_sentence",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "audio_on_reveal",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        # Notifications
        sa.Column(
            "notifications_enabled",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column("reminder_time", sa.String(5), nullable=True),
        sa.Column(
            "streak_alerts",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "review_reminder",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        # Timestamps
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
        sa.UniqueConstraint("user_id"),
    )

    # --- user_languages ---
    op.create_table(
        "user_languages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("target_language", sa.String(10), nullable=False),
        sa.Column(
            "cefr_level",
            sa.Enum("A1", "A2", "B1", "B2", "C1", name="cefrlevel"),
            nullable=False,
        ),
        sa.Column(
            "reading_level",
            sa.Enum("A1", "A2", "B1", "B2", "C1", name="cefrlevel", create_type=False),
            nullable=True,
        ),
        sa.Column(
            "speaking_level",
            sa.Enum("A1", "A2", "B1", "B2", "C1", name="cefrlevel", create_type=False),
            nullable=True,
        ),
        sa.Column(
            "listening_level",
            sa.Enum("A1", "A2", "B1", "B2", "C1", name="cefrlevel", create_type=False),
            nullable=True,
        ),
        sa.Column("interests", sa.JSON(), server_default="[]", nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default="true",
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
            "user_id", "target_language", name="uq_user_target_language"
        ),
    )

    # --- device_tokens ---
    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token", sa.String(512), nullable=False),
        sa.Column(
            "platform",
            sa.String(16),
            server_default="ios",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("token"),
    )

    # --- usage_meters ---
    op.create_table(
        "usage_meters",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "subscription_tier",
            sa.Enum("free", "fluency", name="subscriptiontier", create_type=False),
            nullable=False,
        ),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column(
            "passages_generated",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "talk_seconds",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "books_uploaded",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "listening_seconds",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "translations_used",
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
    )
    op.create_index(
        "ix_usage_meters_user_period",
        "usage_meters",
        ["user_id", "period_start"],
    )


def downgrade() -> None:
    op.drop_table("usage_meters")
    op.drop_table("device_tokens")
    op.drop_table("user_languages")
    op.drop_table("user_settings")
    op.drop_table("users")

    # Drop enum types
    op.execute("DROP TYPE IF EXISTS subscriptiontier")
    op.execute("DROP TYPE IF EXISTS cefrlevel")
    op.execute("DROP TYPE IF EXISTS readingtheme")
    op.execute("DROP TYPE IF EXISTS readingfont")
    op.execute("DROP TYPE IF EXISTS linespacing")
