"""Pydantic schemas for user language endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import CEFRLevel


class UserLanguageCreate(BaseModel):
    """Request body for creating a new target language."""

    target_language: str = Field(
        ..., min_length=2, max_length=10, description="ISO language code"
    )
    cefr_level: CEFRLevel
    interests: list[str] = Field(default_factory=list)


class UserLanguageUpdate(BaseModel):
    """Mutable language fields."""

    cefr_level: CEFRLevel | None = None
    interests: list[str] | None = None
    is_active: bool | None = None
    reading_level: CEFRLevel | None = None
    speaking_level: CEFRLevel | None = None
    listening_level: CEFRLevel | None = None


class UserLanguageResponse(BaseModel):
    """Public representation of a user language."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID
    target_language: str
    cefr_level: CEFRLevel
    reading_level: CEFRLevel | None
    speaking_level: CEFRLevel | None
    listening_level: CEFRLevel | None
    interests: list[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime
