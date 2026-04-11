"""StudySession ORM model for flashcard study sessions."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import CardTypeFilter, StudyMode

if TYPE_CHECKING:
    from app.models.session_review import SessionReview
    from app.models.user import User


class StudySession(Base, UUIDMixin, TimestampMixin):
    """A flashcard study session grouping multiple card reviews."""

    __tablename__ = "study_sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    mode: Mapped[StudyMode] = mapped_column(
        SAEnum(StudyMode, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    card_limit: Mapped[int] = mapped_column(default=25, server_default="25")
    card_type_filter: Mapped[CardTypeFilter | None] = mapped_column(
        SAEnum(CardTypeFilter, values_callable=lambda x: [e.value for e in x]),
        nullable=True,
    )
    total_cards: Mapped[int] = mapped_column(default=0, server_default="0")
    correct_count: Mapped[int] = mapped_column(default=0, server_default="0")
    incorrect_count: Mapped[int] = mapped_column(default=0, server_default="0")
    duration_seconds: Mapped[int | None] = mapped_column(nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(nullable=True)

    # Relationships
    user: Mapped[User] = relationship("User", lazy="selectin")
    session_reviews: Mapped[list[SessionReview]] = relationship(
        "SessionReview",
        back_populates="session",
        lazy="selectin",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return (
            f"<StudySession id={self.id} user_id={self.user_id} "
            f"mode={self.mode} cards={self.total_cards}>"
        )
