"""Pydantic schemas for user profile endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import SubscriptionTier
from app.schemas.user_language import UserLanguageResponse
from app.schemas.user_settings import UserSettingsResponse


class UserResponse(BaseModel):
    """Public representation of a user."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    supabase_uid: str
    email: str
    name: str
    avatar_url: str | None
    native_language: str
    subscription_tier: SubscriptionTier
    daily_goal_minutes: int
    new_words_per_day: int
    auto_adjust_difficulty: bool
    timezone: str
    current_streak: int
    onboarding_completed: bool
    onboarding_step: int
    created_at: datetime
    updated_at: datetime


class UserUpdate(BaseModel):
    """Mutable user profile fields."""

    name: str | None = None
    daily_goal_minutes: int | None = Field(default=None, ge=1, le=120)
    new_words_per_day: int | None = Field(default=None, ge=1, le=100)
    auto_adjust_difficulty: bool | None = None
    timezone: str | None = None
    onboarding_step: int | None = Field(default=None, ge=0, le=8)
    onboarding_completed: bool | None = None


class MeResponse(BaseModel):
    """Composite response for GET /v1/me."""

    model_config = {"from_attributes": True}

    user: UserResponse
    active_language: UserLanguageResponse | None
    settings: UserSettingsResponse | None
