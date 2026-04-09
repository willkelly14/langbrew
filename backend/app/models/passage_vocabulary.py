"""PassageVocabulary ORM model — vocabulary annotations within a passage."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UUIDMixin

if TYPE_CHECKING:
    from app.models.passage import Passage
    from app.models.vocabulary import VocabularyItem


class PassageVocabulary(Base, UUIDMixin):
    """A vocabulary annotation within a reading passage."""

    __tablename__ = "passage_vocabulary"
    __table_args__ = (
        Index("ix_passage_vocabulary_passage_id", "passage_id"),
        Index("ix_passage_vocabulary_vocab_id", "vocabulary_item_id"),
    )

    passage_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("passages.id", ondelete="CASCADE"),
        nullable=False,
    )
    vocabulary_item_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("vocabulary_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    word: Mapped[str] = mapped_column(String(255), nullable=False)
    start_index: Mapped[int] = mapped_column(nullable=False)
    end_index: Mapped[int] = mapped_column(nullable=False)
    is_highlighted: Mapped[bool] = mapped_column(default=True, server_default="true")
    definition: Mapped[str | None] = mapped_column(Text, nullable=True)
    translation: Mapped[str | None] = mapped_column(String(512), nullable=True)
    phonetic: Mapped[str | None] = mapped_column(String(255), nullable=True)
    word_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    example_sentence: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # Relationships
    passage: Mapped[Passage] = relationship(
        "Passage", back_populates="vocabulary_annotations"
    )
    vocabulary_item: Mapped[VocabularyItem | None] = relationship(
        "VocabularyItem", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<PassageVocabulary id={self.id} word={self.word!r}>"
