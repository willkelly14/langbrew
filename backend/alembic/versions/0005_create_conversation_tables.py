"""create conversation tables

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-11

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- conversation_partners ---
    op.create_table(
        "conversation_partners",
        sa.Column("id", sa.String(50), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("personality_tag", sa.String(200), nullable=False),
        sa.Column("system_prompt_template", sa.Text(), nullable=False),
        sa.Column(
            "avatar_url",
            sa.String(500),
            server_default="",
            nullable=False,
        ),
        sa.Column(
            "voice_config",
            sa.JSON(),
            server_default="{}",
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
    )

    # --- conversations ---
    op.create_table(
        "conversations",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("partner_id", sa.String(50), nullable=False),
        sa.Column("topic", sa.String(255), nullable=False),
        sa.Column("language", sa.String(10), nullable=False),
        sa.Column(
            "cefr_level",
            sa.String(2),
            server_default="A2",
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(20),
            server_default="active",
            nullable=False,
        ),
        sa.Column(
            "message_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "total_duration_seconds",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column("last_message_preview", sa.String(200), nullable=True),
        sa.Column("last_message_at", sa.DateTime(), nullable=True),
        sa.Column(
            "has_unread",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column(
            "started_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
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
        sa.ForeignKeyConstraint(["partner_id"], ["conversation_partners.id"]),
    )
    op.create_index(
        "ix_conversations_user_lang_created",
        "conversations",
        ["user_id", "language", sa.text("created_at DESC")],
    )

    # --- messages ---
    op.create_table(
        "messages",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("conversation_id", sa.Uuid(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column(
            "content_type",
            sa.String(20),
            server_default="text",
            nullable=False,
        ),
        sa.Column("text_content", sa.Text(), nullable=True),
        sa.Column("audio_transcription", sa.Text(), nullable=True),
        sa.Column("audio_url", sa.String(500), nullable=True),
        sa.Column("audio_duration_seconds", sa.Integer(), nullable=True),
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
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["conversations.id"], ondelete="CASCADE"
        ),
    )
    op.create_index(
        "ix_messages_conversation_seq",
        "messages",
        ["conversation_id", "sequence_number"],
    )

    # --- conversation_feedback ---
    op.create_table(
        "conversation_feedback",
        sa.Column(
            "id",
            sa.Uuid(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("conversation_id", sa.Uuid(), nullable=False),
        sa.Column(
            "overall_score",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "grammar_score",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "vocabulary_score",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "fluency_score",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "confidence_score",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("strengths", sa.JSON(), nullable=True),
        sa.Column("tips", sa.JSON(), nullable=True),
        sa.Column("corrections", sa.JSON(), nullable=True),
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
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["conversations.id"], ondelete="CASCADE"
        ),
        sa.UniqueConstraint("conversation_id"),
    )

    # Seed conversation partners
    op.execute("""
INSERT INTO conversation_partners (id, name, personality_tag, system_prompt_template, avatar_url, voice_config, created_at, updated_at) VALUES
('mia', 'Mia', 'Friendly · Natural', 'You are a friendly and encouraging conversation partner for language learners. You are warm, patient, and love helping people practice. You ask follow-up questions and show genuine interest in what the student says. You gently guide the conversation to help them use new vocabulary.', '', '{"es": "Vivian", "fr": "Serena", "de": "Ryan", "ja": "Ono_Anna"}', now(), now()),
('carlos', 'Carlos', 'Energetic · Fun', 'You are an enthusiastic and fun conversation partner. You bring energy and humor to conversations while keeping the language level appropriate. You often suggest activities and share fun facts. You use colloquial but clear language.', '', '{"es": "Dylan", "fr": "Eric", "de": "Aiden", "ja": "Uncle_Fu"}', now(), now()),
('elena', 'Elena', 'Calm · Clear', 'You are a calm and clear-spoken conversation partner. You speak slowly and clearly, perfect for beginners. You repeat important phrases naturally and use simple sentence structures. You are patient and never rush the student.', '', '{"es": "Serena", "fr": "Vivian", "de": "Serena", "ja": "Sohee"}', now(), now()),
('lucia', 'Lucía', 'Expressive · Warm', 'You are an expressive and warm conversation partner. You use rich vocabulary and descriptive language while staying at the student level. You share stories and personal anecdotes to make conversations feel real and engaging.', '', '{"es": "Ryan", "fr": "Ryan", "de": "Vivian", "ja": "Vivian"}', now(), now()),
('diego', 'Diego', 'Direct · Practical', 'You are a direct and practical conversation partner. You focus on useful, everyday scenarios and help students practice real-world conversations. You give concise responses and focus on the most important vocabulary and phrases.', '', '{"es": "Aiden", "fr": "Dylan", "de": "Dylan", "ja": "Dylan"}', now(), now()),
('marco', 'Marco', 'Curious · Thoughtful', 'You are a curious and thoughtful conversation partner. You ask interesting questions and explore topics in depth. You help students express complex ideas in simpler ways and encourage them to think critically in the target language.', '', '{"es": "Eric", "fr": "Aiden", "de": "Eric", "ja": "Eric"}', now(), now())
""")


def downgrade() -> None:
    op.drop_table("conversation_feedback")
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_table("conversation_partners")
