"""ReviewEvent ORM model for tracking individual flashcard reviews."""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.vocabulary import VocabularyItem


class ReviewEvent(Base, UUIDMixin, TimestampMixin):
    """Records a single review of a flashcard with SM-2 state changes."""

    __tablename__ = "review_events"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    vocabulary_item_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vocabulary_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("study_sessions.id", ondelete="SET NULL"),
        nullable=True,
    )
    quality: Mapped[int] = mapped_column(nullable=False)
    previous_ease_factor: Mapped[float] = mapped_column(nullable=False)
    new_ease_factor: Mapped[float] = mapped_column(nullable=False)
    previous_interval: Mapped[int] = mapped_column(nullable=False)
    new_interval: Mapped[int] = mapped_column(nullable=False)
    response_time_ms: Mapped[int | None] = mapped_column(nullable=True)

    # Relationships
    user: Mapped[User] = relationship("User", lazy="selectin")
    vocabulary_item: Mapped[VocabularyItem] = relationship(
        "VocabularyItem", lazy="selectin"
    )

    def __repr__(self) -> str:
        return (
            f"<ReviewEvent id={self.id} item_id={self.vocabulary_item_id} "
            f"quality={self.quality}>"
        )
