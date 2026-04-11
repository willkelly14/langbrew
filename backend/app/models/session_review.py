"""SessionReview ORM model linking review events to study sessions."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UUIDMixin

if TYPE_CHECKING:
    from app.models.review_event import ReviewEvent
    from app.models.study_session import StudySession
    from app.models.vocabulary import VocabularyItem


class SessionReview(Base, UUIDMixin):
    """Links a review event to a study session with card ordering."""

    __tablename__ = "session_reviews"

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("study_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    review_event_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("review_events.id", ondelete="CASCADE"),
        nullable=False,
    )
    vocabulary_item_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vocabulary_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    card_order: Mapped[int] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # Relationships
    session: Mapped[StudySession] = relationship(
        "StudySession", back_populates="session_reviews"
    )
    review_event: Mapped[ReviewEvent] = relationship("ReviewEvent", lazy="selectin")
    vocabulary_item: Mapped[VocabularyItem] = relationship(
        "VocabularyItem", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<SessionReview session_id={self.session_id} order={self.card_order}>"
