"""Pydantic schemas for the home screen aggregation endpoint."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel

from app.schemas.user_language import UserLanguageResponse


class WordStats(BaseModel):
    """Vocabulary progress statistics for the home screen."""

    total: int = 0
    learning: int = 0
    mastered: int = 0


class HomeUser(BaseModel):
    """Subset of user data needed by the home screen."""

    name: str
    avatar_url: str | None
    current_streak: int
    streak_week: list[bool]


class HomeResponse(BaseModel):
    """Aggregated response for GET /v1/home."""

    user: HomeUser
    active_language: UserLanguageResponse | None
    cards_due: int
    todays_passage: dict[str, Any] | None
    current_book: dict[str, Any] | None
    recent_books: list[dict[str, Any]]
    word_stats: WordStats
