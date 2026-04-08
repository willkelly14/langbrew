"""UserStreak ORM model for daily activity tracking."""

from __future__ import annotations

import uuid
from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.user import User


class UserStreak(Base, UUIDMixin, TimestampMixin):
    """Tracks daily study activity for a user in a given language."""

    __tablename__ = "user_streaks"
    __table_args__ = (
        UniqueConstraint("user_id", "date", "language", name="uq_user_date_language"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    date: Mapped[date] = mapped_column(nullable=False)
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    minutes_studied: Mapped[int] = mapped_column(default=0, server_default="0")
    passages_read: Mapped[int] = mapped_column(default=0, server_default="0")
    cards_reviewed: Mapped[int] = mapped_column(default=0, server_default="0")
    chats_completed: Mapped[int] = mapped_column(default=0, server_default="0")
    words_learned: Mapped[int] = mapped_column(default=0, server_default="0")

    # Relationship
    user: Mapped[User] = relationship("User", back_populates="streaks")

    def __repr__(self) -> str:
        return (
            f"<UserStreak user_id={self.user_id} "
            f"date={self.date} lang={self.language!r}>"
        )

    @property
    def has_activity(self) -> bool:
        """Return True if any non-zero activity was recorded."""
        return (
            self.minutes_studied > 0
            or self.passages_read > 0
            or self.cards_reviewed > 0
            or self.chats_completed > 0
            or self.words_learned > 0
        )
