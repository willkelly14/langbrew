"""Conversation partner (AI character) reference table."""

from __future__ import annotations

from sqlalchemy import JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class ConversationPartner(Base, TimestampMixin):
    """An AI character that users can practise conversations with."""

    __tablename__ = "conversation_partners"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    personality_tag: Mapped[str] = mapped_column(String(200), nullable=False)
    system_prompt_template: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_url: Mapped[str] = mapped_column(String(500), default="")
    voice_config: Mapped[dict] = mapped_column(JSON, default=dict)

    def __repr__(self) -> str:
        return f"<ConversationPartner id={self.id!r} name={self.name!r}>"
