"""UsageMeter ORM model."""

from __future__ import annotations

import uuid
from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import SubscriptionTier

if TYPE_CHECKING:
    from app.models.user import User


class UsageMeter(Base, UUIDMixin, TimestampMixin):
    """Monthly usage counters for tier-based limits."""

    __tablename__ = "usage_meters"
    __table_args__ = (Index("ix_usage_meters_user_period", "user_id", "period_start"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    subscription_tier: Mapped[SubscriptionTier] = mapped_column(nullable=False)
    period_start: Mapped[date] = mapped_column(nullable=False)
    period_end: Mapped[date] = mapped_column(nullable=False)
    passages_generated: Mapped[int] = mapped_column(default=0, server_default="0")
    talk_seconds: Mapped[int] = mapped_column(default=0, server_default="0")
    books_uploaded: Mapped[int] = mapped_column(default=0, server_default="0")
    listening_seconds: Mapped[int] = mapped_column(default=0, server_default="0")
    translations_used: Mapped[int] = mapped_column(default=0, server_default="0")

    # Relationship
    user: Mapped[User] = relationship("User", back_populates="usage_meters")

    def __repr__(self) -> str:
        return (
            f"<UsageMeter user_id={self.user_id} "
            f"period={self.period_start}..{self.period_end}>"
        )
