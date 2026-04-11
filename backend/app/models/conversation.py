"""Conversation ORM model for AI talk sessions."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.conversation_partner import ConversationPartner


class Conversation(Base, UUIDMixin, TimestampMixin):
    """A user's AI conversation session."""

    __tablename__ = "conversations"
    __table_args__ = (
        Index(
            "ix_conversations_user_lang_created",
            "user_id",
            "language",
            "created_at",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    partner_id: Mapped[str] = mapped_column(
        ForeignKey("conversation_partners.id"),
        nullable=False,
    )
    topic: Mapped[str] = mapped_column(String(255), nullable=False)
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    cefr_level: Mapped[str] = mapped_column(
        String(2),
        nullable=False,
        default="A2",
        server_default="A2",
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="active",
        server_default="active",
    )
    message_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    total_duration_seconds: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    last_message_preview: Mapped[str | None] = mapped_column(String(200), nullable=True)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    has_unread: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
    )
    started_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # Relationships
    partner: Mapped[ConversationPartner] = relationship(
        "ConversationPartner",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return f"<Conversation id={self.id} topic={self.topic!r}>"
