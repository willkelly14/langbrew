"""Pydantic schemas for passage endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import CEFRLevel, GenerateMode, PassageLength, PassageStyle

# ---------------------------------------------------------------------------
# Vocabulary annotation (embedded in passage responses)
# ---------------------------------------------------------------------------


class PassageVocabularyResponse(BaseModel):
    """A vocabulary annotation within a passage."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    passage_id: uuid.UUID
    word: str
    start_index: int
    end_index: int
    is_highlighted: bool
    definition: str | None
    translation: str | None
    phonetic: str | None
    word_type: str | None
    example_sentence: str | None
    vocabulary_item_id: uuid.UUID | None
    created_at: datetime


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------


class GeneratePassageRequest(BaseModel):
    """Request body for POST /v1/passages/generate."""

    mode: GenerateMode = GenerateMode.AUTO
    topic: str | None = Field(default=None, max_length=255)
    cefr_level: CEFRLevel | None = None
    style: PassageStyle | None = None
    length: PassageLength | None = None


class PassageUpdateRequest(BaseModel):
    """Request body for PATCH /v1/passages/:id."""

    reading_progress: float | None = Field(default=None, ge=0.0, le=1.0)
    bookmark_position: int | None = Field(default=None, ge=0)


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------


class PassageResponse(BaseModel):
    """Full passage with vocabulary annotations."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID
    user_language_id: uuid.UUID
    title: str
    content: str
    language: str
    cefr_level: CEFRLevel
    topic: str
    word_count: int
    estimated_minutes: int
    known_word_percentage: float | None
    is_generated: bool
    source_book_id: uuid.UUID | None
    source_chapter_number: int | None
    style: PassageStyle | None
    length: PassageLength | None
    reading_progress: float
    bookmark_position: int | None
    vocabulary_annotations: list[PassageVocabularyResponse]
    created_at: datetime
    updated_at: datetime


class PassageListItem(BaseModel):
    """Passage summary for list endpoints (no full content)."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    title: str
    language: str
    cefr_level: CEFRLevel
    topic: str
    word_count: int
    estimated_minutes: int
    is_generated: bool
    style: PassageStyle | None
    length: PassageLength | None
    reading_progress: float
    excerpt: str = ""
    created_at: datetime
    updated_at: datetime


class PaginatedPassagesResponse(BaseModel):
    """Paginated list of passages."""

    items: list[PassageListItem]
    next_cursor: str | None = None
