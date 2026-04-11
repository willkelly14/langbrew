"""Dictionary ORM models — DictionaryEntry and DictionaryForm."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import JSON, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin


class DictionaryEntry(Base, UUIDMixin, TimestampMixin):
    """A bilingual dictionary headword sourced from Wiktionary."""

    __tablename__ = "dictionary_entries"
    __table_args__ = (
        Index("ix_dictionary_entries_lang_lemma", "language", "lemma"),
        Index("ix_dictionary_entries_lang_freq", "language", "frequency_rank"),
        Index("ix_dictionary_entries_lang_cefr", "language", "cefr_estimate"),
        UniqueConstraint(
            "language",
            "lemma",
            "word_type",
            name="uq_dictionary_lang_lemma_word_type",
        ),
    )

    language: Mapped[str] = mapped_column(String(10), nullable=False)
    lemma: Mapped[str] = mapped_column(String(255), nullable=False)
    display_form: Mapped[str | None] = mapped_column(String(255), nullable=True)
    word_type: Mapped[str] = mapped_column(String(64), nullable=False)
    phonetic: Mapped[str | None] = mapped_column(String(255), nullable=True)
    frequency_rank: Mapped[int | None] = mapped_column(nullable=True)
    cefr_estimate: Mapped[str | None] = mapped_column(String(2), nullable=True)
    senses: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    etymology: Mapped[str | None] = mapped_column(Text, nullable=True)
    synonyms: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    source: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default="wiktionary"
    )
    source_version: Mapped[str | None] = mapped_column(String(32), nullable=True)

    # Relationships
    forms: Mapped[list[DictionaryForm]] = relationship(
        "DictionaryForm",
        back_populates="dictionary_entry",
        lazy="selectin",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return (
            f"<DictionaryEntry id={self.id} "
            f"language={self.language!r} lemma={self.lemma!r}>"
        )


class DictionaryForm(Base, UUIDMixin):
    """An inflected surface form mapping back to a dictionary headword."""

    __tablename__ = "dictionary_forms"
    __table_args__ = (
        Index("ix_dictionary_forms_lang_surface", "language", "surface_form"),
        UniqueConstraint(
            "language",
            "surface_form",
            "word_type",
            name="uq_dictionary_form_lang_surface_word_type",
        ),
    )

    language: Mapped[str] = mapped_column(String(10), nullable=False)
    surface_form: Mapped[str] = mapped_column(String(255), nullable=False)
    lemma: Mapped[str] = mapped_column(String(255), nullable=False)
    word_type: Mapped[str] = mapped_column(String(64), nullable=False)
    dictionary_entry_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("dictionary_entries.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Relationships
    dictionary_entry: Mapped[DictionaryEntry] = relationship(
        "DictionaryEntry", back_populates="forms"
    )

    def __repr__(self) -> str:
        return (
            f"<DictionaryForm id={self.id} "
            f"surface_form={self.surface_form!r} lemma={self.lemma!r}>"
        )
