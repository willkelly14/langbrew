"""User ORM model."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import SubscriptionTier

if TYPE_CHECKING:
    from app.models.device_token import DeviceToken
    from app.models.usage_meter import UsageMeter
    from app.models.user_language import UserLanguage
    from app.models.user_settings import UserSettings
    from app.models.user_streak import UserStreak


class User(Base, UUIDMixin, TimestampMixin):
    """Represents an authenticated LangBrew user."""

    __tablename__ = "users"

    supabase_uid: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    first_name: Mapped[str] = mapped_column(String(255), default="", server_default="")
    avatar_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    native_language: Mapped[str] = mapped_column(
        String(10), default="en", server_default="en"
    )
    subscription_tier: Mapped[SubscriptionTier] = mapped_column(
        default=SubscriptionTier.FREE,
        server_default=SubscriptionTier.FREE.value,
    )
    subscription_expires_at: Mapped[datetime | None] = mapped_column(nullable=True)
    app_store_transaction_id: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    daily_goal_minutes: Mapped[int] = mapped_column(default=10, server_default="10")
    new_words_per_day: Mapped[int] = mapped_column(default=10, server_default="10")
    auto_adjust_difficulty: Mapped[bool] = mapped_column(
        default=True, server_default="true"
    )
    timezone: Mapped[str] = mapped_column(
        String(64), default="UTC", server_default="UTC"
    )
    current_streak: Mapped[int] = mapped_column(default=0, server_default="0")
    onboarding_completed: Mapped[bool] = mapped_column(
        default=False, server_default="false"
    )
    onboarding_step: Mapped[int] = mapped_column(default=0, server_default="0")

    # Relationships
    settings: Mapped[UserSettings | None] = relationship(
        "UserSettings",
        back_populates="user",
        uselist=False,
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    languages: Mapped[list[UserLanguage]] = relationship(
        "UserLanguage",
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    device_tokens: Mapped[list[DeviceToken]] = relationship(
        "DeviceToken",
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    usage_meters: Mapped[list[UsageMeter]] = relationship(
        "UsageMeter",
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    streaks: Mapped[list[UserStreak]] = relationship(
        "UserStreak",
        back_populates="user",
        lazy="noload",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email!r}>"

    @property
    def active_language(self) -> UserLanguage | None:
        """Return the currently active target language, if any."""
        for lang in self.languages:
            if lang.is_active:
                return lang
        return None

    @property
    def active_language_id(self) -> uuid.UUID | None:
        """Shortcut to the active language's id."""
        active = self.active_language
        return active.id if active else None
