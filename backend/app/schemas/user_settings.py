"""Pydantic schemas for user settings endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import LineSpacing, ReadingFont, ReadingTheme


class UserSettingsResponse(BaseModel):
    """Public representation of user settings."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID

    # Reading
    reading_theme: ReadingTheme
    reading_font: ReadingFont
    font_size: int
    line_spacing: LineSpacing
    vocabulary_highlights: bool
    auto_play_audio: bool
    highlight_following: bool
    preferred_voice_id: str | None
    voice_speed: float

    # Talk
    talk_voice_style: str
    talk_correction_style: str
    show_transcript: bool
    auto_save_words: bool
    session_length_minutes: int

    # Flashcard
    reviews_per_session: int
    show_example_sentence: bool
    audio_on_reveal: bool

    # Notifications
    notifications_enabled: bool
    reminder_time: str | None
    streak_alerts: bool
    review_reminder: bool

    created_at: datetime
    updated_at: datetime


class UserSettingsUpdate(BaseModel):
    """All 22 settings fields, each optional."""

    # Reading
    reading_theme: ReadingTheme | None = None
    reading_font: ReadingFont | None = None
    font_size: int | None = Field(default=None, ge=10, le=32)
    line_spacing: LineSpacing | None = None
    vocabulary_highlights: bool | None = None
    auto_play_audio: bool | None = None
    highlight_following: bool | None = None
    preferred_voice_id: str | None = None
    voice_speed: float | None = Field(default=None, ge=0.5, le=2.0)

    # Talk
    talk_voice_style: str | None = None
    talk_correction_style: str | None = None
    show_transcript: bool | None = None
    auto_save_words: bool | None = None
    session_length_minutes: int | None = Field(default=None, ge=1, le=30)

    # Flashcard
    reviews_per_session: int | None = Field(default=None, ge=5, le=100)
    show_example_sentence: bool | None = None
    audio_on_reveal: bool | None = None

    # Notifications
    notifications_enabled: bool | None = None
    reminder_time: str | None = None
    streak_alerts: bool | None = None
    review_reminder: bool | None = None
