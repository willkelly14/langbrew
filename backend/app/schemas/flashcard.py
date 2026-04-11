"""Pydantic schemas for flashcard review, study sessions, and stats."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums import (
    CardTypeFilter,
    StudyMode,
    VocabularyStatus,
    VocabularyType,
)

# ---------------------------------------------------------------------------
# Flashcard card (vocabulary item projected for review)
# ---------------------------------------------------------------------------


class FlashcardCardResponse(BaseModel):
    """A vocabulary item projected as a flashcard for review."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    text: str
    translation: str
    phonetic: str | None
    word_type: str | None
    definitions: list[dict[str, Any]] | None
    example_sentence: str | None
    language: str
    type: VocabularyType
    status: VocabularyStatus
    ease_factor: float
    interval: int
    repetitions: int
    next_review_date: date | None
    times_reviewed: int
    times_correct: int
    last_reviewed_at: datetime | None
    created_at: datetime


class FlashcardDueResponse(BaseModel):
    """List of vocabulary items due for review."""

    items: list[FlashcardCardResponse]
    total_due: int


class FlashcardDueCountResponse(BaseModel):
    """Just the count of cards due for review."""

    count: int


# ---------------------------------------------------------------------------
# Review
# ---------------------------------------------------------------------------


class FlashcardReviewRequest(BaseModel):
    """Request body for submitting a flashcard review."""

    quality: int = Field(..., ge=1, le=3, description="1=wrong, 3=right")
    response_time_ms: int | None = Field(default=None, ge=0)


class FlashcardReviewResponse(BaseModel):
    """Updated SM-2 values after a review."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    text: str
    translation: str
    status: VocabularyStatus
    ease_factor: float
    interval: int
    repetitions: int
    next_review_date: date | None
    times_reviewed: int
    times_correct: int
    last_reviewed_at: datetime | None
    review_event_id: uuid.UUID


# ---------------------------------------------------------------------------
# Study Sessions
# ---------------------------------------------------------------------------


class StudySessionCreate(BaseModel):
    """Request body for creating a study session."""

    mode: StudyMode
    card_limit: int = Field(default=25, ge=1, le=100)
    card_type_filter: CardTypeFilter | None = None


class StudySessionResponse(BaseModel):
    """Study session summary."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    language: str
    mode: StudyMode
    card_limit: int
    card_type_filter: CardTypeFilter | None
    total_cards: int
    correct_count: int
    incorrect_count: int
    duration_seconds: int | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class SessionReviewCardResponse(BaseModel):
    """Per-card breakdown within a study session."""

    card_order: int
    vocabulary_item_id: uuid.UUID
    text: str
    translation: str
    quality: int
    previous_ease_factor: float
    new_ease_factor: float
    previous_interval: int
    new_interval: int
    response_time_ms: int | None


class StudySessionDetailResponse(BaseModel):
    """Full study session detail with per-card breakdown."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    language: str
    mode: StudyMode
    card_limit: int
    card_type_filter: CardTypeFilter | None
    total_cards: int
    correct_count: int
    incorrect_count: int
    duration_seconds: int | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime
    cards: list[SessionReviewCardResponse]


class StudySessionCompleteRequest(BaseModel):
    """Request body for completing a study session."""

    duration_seconds: int = Field(..., ge=0)


class PaginatedStudySessionsResponse(BaseModel):
    """Paginated list of study sessions."""

    items: list[StudySessionResponse]
    next_cursor: str | None = None


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------


class MasteryBreakdown(BaseModel):
    """Counts of vocabulary items by status."""

    new: int = 0
    learning: int = 0
    known: int = 0
    mastered: int = 0
    total: int = 0


class StreakData(BaseModel):
    """User review streak information."""

    current: int = 0
    longest: int = 0
    today_reviewed: bool = False


class AccuracyData(BaseModel):
    """Review accuracy statistics."""

    total_reviews: int = 0
    correct: int = 0
    incorrect: int = 0
    accuracy_percentage: float = 0.0


class ForecastDay(BaseModel):
    """Predicted review count for a single day."""

    date: date
    count: int


class VelocityData(BaseModel):
    """Learning velocity metrics."""

    words_per_day_7d: float = 0.0
    words_per_day_30d: float = 0.0
    new_words_this_week: int = 0


class TimeSpentData(BaseModel):
    """Time spent reviewing."""

    total_seconds: int = 0
    average_session_seconds: float = 0.0
    sessions_count: int = 0


class FlashcardStatsResponse(BaseModel):
    """Full flashcard statistics."""

    mastery_breakdown: MasteryBreakdown
    streak_data: StreakData
    accuracy: AccuracyData
    forecast: list[ForecastDay]
    velocity: VelocityData
    time_spent: TimeSpentData


# ---------------------------------------------------------------------------
# Vocabulary listing (enhanced)
# ---------------------------------------------------------------------------


class VocabularyListItem(BaseModel):
    """Vocabulary item summary for list endpoints."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    text: str
    translation: str
    phonetic: str | None
    word_type: str | None
    language: str
    type: VocabularyType
    status: VocabularyStatus
    ease_factor: float
    interval: int
    repetitions: int
    next_review_date: date | None
    times_reviewed: int
    times_correct: int
    last_reviewed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PaginatedVocabularyResponse(BaseModel):
    """Paginated list of vocabulary items."""

    items: list[VocabularyListItem]
    next_cursor: str | None = None


class VocabularyStatsResponse(BaseModel):
    """Aggregate vocabulary statistics."""

    total: int = 0
    new: int = 0
    learning: int = 0
    known: int = 0
    mastered: int = 0
    words: int = 0
    phrases: int = 0
    sentences: int = 0


class VocabularyBatchCreateItem(BaseModel):
    """A single item in a batch create request."""

    text: str = Field(..., min_length=1, max_length=512)
    translation: str = Field(..., min_length=1, max_length=512)
    phonetic: str | None = Field(default=None, max_length=255)
    word_type: str | None = Field(default=None, max_length=64)
    definitions: list[dict[str, Any]] | None = None
    example_sentence: str | None = None
    language: str = Field(..., min_length=2, max_length=10)
    type: VocabularyType = VocabularyType.WORD


class VocabularyBatchCreateRequest(BaseModel):
    """Request body for batch creating vocabulary items."""

    items: list[VocabularyBatchCreateItem] = Field(..., min_length=1, max_length=100)


class VocabularyBatchCreateResponse(BaseModel):
    """Response from batch creating vocabulary items."""

    created: int
    skipped: int
    items: list[VocabularyListItem]


class VocabularyUpdateRequest(BaseModel):
    """Request body for updating a vocabulary item."""

    status: VocabularyStatus | None = None
    translation: str | None = Field(default=None, max_length=512)
    phonetic: str | None = Field(default=None, max_length=255)
    word_type: str | None = Field(default=None, max_length=64)
    definitions: list[dict[str, Any]] | None = None
    example_sentence: str | None = None
    reset_sm2: bool = False
