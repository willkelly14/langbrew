"""UserLanguage ORM model."""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import JSON, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import CEFRLevel

if TYPE_CHECKING:
    from app.models.user import User


class UserLanguage(Base, UUIDMixin, TimestampMixin):
    """A target language a user is studying."""

    __tablename__ = "user_languages"
    __table_args__ = (
        UniqueConstraint("user_id", "target_language", name="uq_user_target_language"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    target_language: Mapped[str] = mapped_column(String(10), nullable=False)
    cefr_level: Mapped[CEFRLevel] = mapped_column(nullable=False)
    reading_level: Mapped[CEFRLevel | None] = mapped_column(nullable=True)
    speaking_level: Mapped[CEFRLevel | None] = mapped_column(nullable=True)
    listening_level: Mapped[CEFRLevel | None] = mapped_column(nullable=True)
    interests: Mapped[list[str]] = mapped_column(
        JSON, default=list, server_default="[]"
    )
    is_active: Mapped[bool] = mapped_column(default=True, server_default="true")

    # Relationship
    user: Mapped[User] = relationship("User", back_populates="languages")

    def __repr__(self) -> str:
        return (
            f"<UserLanguage user_id={self.user_id} "
            f"lang={self.target_language!r} level={self.cefr_level}>"
        )
