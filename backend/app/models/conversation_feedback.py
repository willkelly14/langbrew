"""Post-conversation feedback ORM model."""

from __future__ import annotations

import uuid

from sqlalchemy import JSON, ForeignKey, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDMixin


class ConversationFeedback(Base, UUIDMixin, TimestampMixin):
    """AI-generated feedback summary for a completed conversation."""

    __tablename__ = "conversation_feedback"

    conversation_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    overall_score: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    grammar_score: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    vocabulary_score: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    fluency_score: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    confidence_score: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
    )
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    strengths: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    tips: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    corrections: Mapped[list | None] = mapped_column(JSON, nullable=True)

    def __repr__(self) -> str:
        return (
            f"<ConversationFeedback id={self.id}"
            f" conversation_id={self.conversation_id}>"
        )
