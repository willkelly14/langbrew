"""Passage ORM model."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import CEFRLevel, PassageLength, PassageStyle

if TYPE_CHECKING:
    from app.models.passage_vocabulary import PassageVocabulary
    from app.models.user import User
    from app.models.user_language import UserLanguage


class Passage(Base, UUIDMixin, TimestampMixin):
    """An AI-generated or book-sourced reading passage."""

    __tablename__ = "passages"
    __table_args__ = (
        Index("ix_passages_user_language", "user_id", "language"),
        Index("ix_passages_user_created", "user_id", "created_at"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_language_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("user_languages.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    cefr_level: Mapped[CEFRLevel] = mapped_column(nullable=False)
    topic: Mapped[str] = mapped_column(String(255), nullable=False)
    word_count: Mapped[int] = mapped_column(nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(nullable=False)
    known_word_percentage: Mapped[float | None] = mapped_column(nullable=True)
    is_generated: Mapped[bool] = mapped_column(default=True, server_default="true")
    source_book_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    source_chapter_number: Mapped[int | None] = mapped_column(nullable=True)
    style: Mapped[PassageStyle | None] = mapped_column(nullable=True)
    length: Mapped[PassageLength | None] = mapped_column(nullable=True)
    reading_progress: Mapped[float] = mapped_column(default=0.0, server_default="0.0")
    bookmark_position: Mapped[int | None] = mapped_column(nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Relationships
    user: Mapped[User] = relationship("User", lazy="selectin")
    user_language: Mapped[UserLanguage] = relationship("UserLanguage", lazy="selectin")
    vocabulary_annotations: Mapped[list[PassageVocabulary]] = relationship(
        "PassageVocabulary",
        back_populates="passage",
        lazy="selectin",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Passage id={self.id} title={self.title!r}>"
