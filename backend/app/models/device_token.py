"""DeviceToken ORM model."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UUIDMixin

if TYPE_CHECKING:
    from app.models.user import User


class DeviceToken(Base, UUIDMixin):
    """A push-notification device token registered by a user."""

    __tablename__ = "device_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    token: Mapped[str] = mapped_column(String(512), unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(
        String(16), default="ios", server_default="ios"
    )
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # Relationship
    user: Mapped[User] = relationship("User", back_populates="device_tokens")

    def __repr__(self) -> str:
        return f"<DeviceToken user_id={self.user_id} platform={self.platform!r}>"
