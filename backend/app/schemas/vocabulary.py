"""Pydantic schemas for vocabulary endpoints."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums import SourceType, VocabularyStatus, VocabularyType

# ---------------------------------------------------------------------------
# Encounter
# ---------------------------------------------------------------------------


class VocabularyEncounterResponse(BaseModel):
    """A recorded encounter of a vocabulary item."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    source_type: SourceType
    source_id: uuid.UUID
    context_sentence: str
    created_at: datetime


# ---------------------------------------------------------------------------
# Vocabulary Item
# ---------------------------------------------------------------------------


class VocabularyItemCreate(BaseModel):
    """Request body for creating a vocabulary item."""

    text: str = Field(..., min_length=1, max_length=512)
    translation: str = Field(..., min_length=1, max_length=512)
    phonetic: str | None = Field(default=None, max_length=255)
    word_type: str | None = Field(default=None, max_length=64)
    definitions: list[dict[str, Any]] | None = None
    example_sentence: str | None = None
    language: str = Field(..., min_length=2, max_length=10)
    type: VocabularyType = VocabularyType.WORD
    source_type: SourceType | None = None
    source_id: uuid.UUID | None = None
    context_sentence: str | None = None


class VocabularyItemResponse(BaseModel):
    """Full vocabulary item response."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID
    user_language_id: uuid.UUID
    language: str
    type: VocabularyType
    text: str
    translation: str
    phonetic: str | None
    word_type: str | None
    definitions: list[dict[str, Any]] | None
    example_sentence: str | None
    status: VocabularyStatus
    ease_factor: float
    interval: int
    repetitions: int
    next_review_date: date | None
    times_reviewed: int
    times_correct: int
    last_reviewed_at: datetime | None
    encounters: list[VocabularyEncounterResponse]
    created_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# Define / Translate
# ---------------------------------------------------------------------------


class DefineRequest(BaseModel):
    """Request body for word definition lookup."""

    word: str = Field(..., min_length=1, max_length=255)
    language: str = Field(..., min_length=2, max_length=10)
    context_sentence: str | None = None


class DefinitionEntry(BaseModel):
    """A single definition entry."""

    definition: str
    example: str = ""
    meaning: str = ""


class DefineResponse(BaseModel):
    """Response from word definition lookup."""

    word: str
    phonetic: str | None = None
    word_type: str | None = None
    definitions: list[DefinitionEntry]
    example_sentence: str | None = None


class TranslateRequest(BaseModel):
    """Request body for phrase/sentence translation."""

    text: str = Field(..., min_length=1, max_length=2000)
    source_language: str = Field(..., min_length=2, max_length=10)
    target_language: str = Field(..., min_length=2, max_length=10)
    context: str | None = None


class TranslateResponse(BaseModel):
    """Response from translation."""

    text: str
    translation: str
