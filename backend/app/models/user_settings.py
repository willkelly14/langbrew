"""UserSettings ORM model."""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin
from app.models.enums import LineSpacing, ReadingFont, ReadingTheme

if TYPE_CHECKING:
    from app.models.user import User


class UserSettings(Base, UUIDMixin, TimestampMixin):
    """Per-user application preferences."""

    __tablename__ = "user_settings"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # -- Reading settings --
    reading_theme: Mapped[ReadingTheme] = mapped_column(
        SAEnum(ReadingTheme, values_callable=lambda x: [e.value for e in x]),
        default=ReadingTheme.LIGHT,
        server_default=ReadingTheme.LIGHT.value,
    )
    reading_font: Mapped[ReadingFont] = mapped_column(
        SAEnum(ReadingFont, values_callable=lambda x: [e.value for e in x]),
        default=ReadingFont.SERIF,
        server_default=ReadingFont.SERIF.value,
    )
    font_size: Mapped[int] = mapped_column(default=16, server_default="16")
    line_spacing: Mapped[LineSpacing] = mapped_column(
        SAEnum(LineSpacing, values_callable=lambda x: [e.value for e in x]),
        default=LineSpacing.NORMAL,
        server_default=LineSpacing.NORMAL.value,
    )
    vocabulary_highlights: Mapped[bool] = mapped_column(
        default=True, server_default="true"
    )
    auto_play_audio: Mapped[bool] = mapped_column(default=False, server_default="false")
    highlight_following: Mapped[bool] = mapped_column(
        default=True, server_default="true"
    )
    preferred_voice_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    voice_speed: Mapped[float] = mapped_column(default=1.0, server_default="1.0")

    # -- Talk settings --
    talk_voice_style: Mapped[str] = mapped_column(
        String(64), default="natural", server_default="natural"
    )
    talk_correction_style: Mapped[str] = mapped_column(
        String(64), default="gentle", server_default="gentle"
    )
    show_transcript: Mapped[bool] = mapped_column(default=True, server_default="true")
    auto_save_words: Mapped[bool] = mapped_column(default=True, server_default="true")
    session_length_minutes: Mapped[int] = mapped_column(default=5, server_default="5")

    # -- Flashcard settings --
    reviews_per_session: Mapped[int] = mapped_column(default=20, server_default="20")
    show_example_sentence: Mapped[bool] = mapped_column(
        default=True, server_default="true"
    )
    audio_on_reveal: Mapped[bool] = mapped_column(default=True, server_default="true")

    # -- Notification settings --
    notifications_enabled: Mapped[bool] = mapped_column(
        default=True, server_default="true"
    )
    reminder_time: Mapped[str | None] = mapped_column(String(5), nullable=True)
    streak_alerts: Mapped[bool] = mapped_column(default=True, server_default="true")
    review_reminder: Mapped[bool] = mapped_column(default=True, server_default="true")

    # Relationship
    user: Mapped[User] = relationship("User", back_populates="settings")

    def __repr__(self) -> str:
        return f"<UserSettings user_id={self.user_id}>"
