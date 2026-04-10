"""Vocabulary ORM models — VocabularyItem and VocabularyEncounter."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import JSON, ForeignKey, Index, String, Text, UniqueConstraint, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import SourceType, VocabularyStatus, VocabularyType

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.user_language import UserLanguage


class VocabularyItem(Base, UUIDMixin, TimestampMixin):
    """A word, phrase, or sentence in the user's language bank."""

    __tablename__ = "vocabulary_items"
    __table_args__ = (
        Index(
            "ix_vocabulary_items_user_lang_review",
            "user_id",
            "language",
            "next_review_date",
        ),
        Index(
            "ix_vocabulary_items_user_lang_status",
            "user_id",
            "language",
            "status",
        ),
        UniqueConstraint(
            "user_id",
            "language",
            "text",
            name="uq_vocabulary_user_lang_text",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_language_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("user_languages.id", ondelete="CASCADE"),
        nullable=False,
    )
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    type: Mapped[VocabularyType] = mapped_column(
        SAEnum(VocabularyType, values_callable=lambda x: [e.value for e in x]),
        default=VocabularyType.WORD,
        server_default=VocabularyType.WORD.value,
    )
    text: Mapped[str] = mapped_column(String(512), nullable=False)
    translation: Mapped[str] = mapped_column(String(512), nullable=False)
    phonetic: Mapped[str | None] = mapped_column(String(255), nullable=True)
    word_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    definitions: Mapped[list[dict[str, Any]] | None] = mapped_column(
        JSON, nullable=True
    )
    example_sentence: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[VocabularyStatus] = mapped_column(
        SAEnum(VocabularyStatus, values_callable=lambda x: [e.value for e in x]),
        default=VocabularyStatus.NEW,
        server_default=VocabularyStatus.NEW.value,
    )
    ease_factor: Mapped[float] = mapped_column(default=2.5, server_default="2.5")
    interval: Mapped[int] = mapped_column(default=0, server_default="0")
    repetitions: Mapped[int] = mapped_column(default=0, server_default="0")
    next_review_date: Mapped[date | None] = mapped_column(nullable=True)
    times_reviewed: Mapped[int] = mapped_column(default=0, server_default="0")
    times_correct: Mapped[int] = mapped_column(default=0, server_default="0")
    last_reviewed_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Relationships
    user: Mapped[User] = relationship("User", lazy="selectin")
    user_language: Mapped[UserLanguage] = relationship("UserLanguage", lazy="selectin")
    encounters: Mapped[list[VocabularyEncounter]] = relationship(
        "VocabularyEncounter",
        back_populates="vocabulary_item",
        lazy="selectin",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<VocabularyItem id={self.id} text={self.text!r}>"


class VocabularyEncounter(Base, UUIDMixin):
    """Records where and when a vocabulary item was encountered."""

    __tablename__ = "vocabulary_encounters"
    __table_args__ = (
        Index("ix_vocabulary_encounters_item_id", "vocabulary_item_id"),
        Index("ix_vocabulary_encounters_source", "source_type", "source_id"),
    )

    vocabulary_item_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vocabulary_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    source_type: Mapped[SourceType] = mapped_column(
        SAEnum(SourceType, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    source_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    context_sentence: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # Relationship
    vocabulary_item: Mapped[VocabularyItem] = relationship(
        "VocabularyItem", back_populates="encounters"
    )

    def __repr__(self) -> str:
        return (
            f"<VocabularyEncounter id={self.id} "
            f"source={self.source_type}:{self.source_id}>"
        )
