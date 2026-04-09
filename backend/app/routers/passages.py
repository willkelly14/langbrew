"""Endpoints for AI passage generation and management."""

from __future__ import annotations

import json
import uuid  # noqa: TC003
from typing import TYPE_CHECKING, Any

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sse_starlette.sse import EventSourceResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.middleware.rate_limit import rate_limit_ai, rate_limit_default
from app.middleware.usage_meter import increment_passages_used
from app.models.enums import CEFRLevel  # noqa: TC001
from app.schemas.passage import (
    GeneratePassageRequest,
    PaginatedPassagesResponse,
    PassageResponse,
    PassageUpdateRequest,
)
from app.services import ai_service, passage_service
from app.services.user_service import get_or_create_usage_meter, get_or_create_user

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()

router = APIRouter(prefix="/passages", tags=["passages"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up (or create) the DB user for the authenticated JWT subject."""
    return await get_or_create_user(db, auth.sub, auth.email)


# ---------------------------------------------------------------------------
# POST /v1/passages/generate — SSE streaming passage generation
# ---------------------------------------------------------------------------


@router.post("/generate")
async def generate_passage(
    body: GeneratePassageRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_ai),
) -> EventSourceResponse:
    """Generate a new reading passage via AI (SSE streaming).

    The response is an SSE stream with the following event types:
    - ``chunk``: partial passage content as it streams
    - ``complete``: final passage JSON with id and metadata
    - ``error``: if something goes wrong during generation
    """
    user = await _resolve_user(db, auth)

    # Check usage limit
    meter = await get_or_create_usage_meter(db, user.id, user.subscription_tier)
    from app.middleware.usage_meter import _get_limit

    limit = _get_limit(user.subscription_tier, "passages_generated")
    if meter.passages_generated >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": {
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "message": (
                        "Monthly passage limit reached. "
                        "Upgrade to Fluency for 1,000 passages/month."
                    ),
                    "details": {
                        "limit": limit,
                        "used": meter.passages_generated,
                        "resource": "passages",
                    },
                }
            },
        )

    # Resolve language and defaults
    active_lang = user.active_language
    if active_lang is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "NO_ACTIVE_LANGUAGE",
                    "message": "You must set an active target language first.",
                    "details": {},
                }
            },
        )

    language = active_lang.target_language
    cefr_level = (
        body.cefr_level.value
        if body.cefr_level
        else (active_lang.reading_level or active_lang.cefr_level).value
    )
    interests = active_lang.interests or []
    topic = body.topic or (interests[0] if interests else "daily life")
    style = body.style.value if body.style else None
    length = body.length.value if body.length else None

    # Capture values needed for the async generator closure
    user_id = user.id
    user_language_id = active_lang.id
    subscription_tier = user.subscription_tier

    async def event_generator() -> AsyncGenerator[dict[str, Any], None]:
        """Yield SSE events as the passage streams in."""
        try:
            async for chunk in ai_service.generate_passage_stream(
                language=language,
                cefr_level=cefr_level,
                topic=topic,
                style=style,
                length=length,
                interests=interests,
            ):
                if chunk.startswith("[FINAL]"):
                    # Parse and store the completed passage
                    raw_json = chunk[7:]  # Strip "[FINAL]" prefix
                    try:
                        parsed = ai_service.parse_passage_json(raw_json)
                        vocabulary_data = parsed.get("vocabulary", [])

                        passage = await passage_service.create_passage(
                            db,
                            user_id,
                            user_language_id,
                            passage_data=parsed,
                            vocabulary_data=vocabulary_data,
                            language=language,
                            cefr_level=cefr_level,
                            style=style,
                            length=length,
                        )
                        await increment_passages_used(
                            db, user_id, subscription_tier
                        )
                        await db.commit()

                        yield {
                            "event": "complete",
                            "data": json.dumps(
                                {
                                    "passage_id": str(passage.id),
                                    "title": parsed.get("title", ""),
                                    "word_count": passage.word_count,
                                }
                            ),
                        }
                    except Exception:
                        logger.exception("passage_parse_store_error")
                        yield {
                            "event": "error",
                            "data": json.dumps(
                                {
                                    "error": {
                                        "code": "GENERATION_FAILED",
                                        "message": (
                                            "Failed to parse or store the passage."
                                        ),
                                        "details": {},
                                    }
                                }
                            ),
                        }
                else:
                    yield {"event": "chunk", "data": chunk}
        except Exception:
            logger.exception("passage_stream_error")
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "error": {
                            "code": "GENERATION_FAILED",
                            "message": "An error occurred during passage generation.",
                            "details": {},
                        }
                    }
                ),
            }

    return EventSourceResponse(event_generator())


# ---------------------------------------------------------------------------
# GET /v1/passages — List passages
# ---------------------------------------------------------------------------


@router.get("", response_model=PaginatedPassagesResponse)
async def list_passages(
    search: str | None = Query(default=None, max_length=255),
    cefr_level: CEFRLevel | None = Query(default=None),
    topic: str | None = Query(default=None, max_length=255),
    is_generated: bool | None = Query(default=None),
    sort_by: str = Query(default="date", pattern="^(date|difficulty|topic)$"),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PaginatedPassagesResponse:
    """List the current user's passages with filtering and pagination."""
    user = await _resolve_user(db, auth)

    items, next_cursor = await passage_service.list_passages(
        db,
        user.id,
        search=search,
        cefr_level=cefr_level.value if cefr_level else None,
        topic=topic,
        is_generated=is_generated,
        sort_by=sort_by,
        sort_order=sort_order,
        cursor=cursor,
        limit=limit,
    )

    return PaginatedPassagesResponse(items=items, next_cursor=next_cursor)


# ---------------------------------------------------------------------------
# GET /v1/passages/{passage_id} — Get passage with vocabulary
# ---------------------------------------------------------------------------


@router.get("/{passage_id}", response_model=PassageResponse)
async def get_passage(
    passage_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PassageResponse:
    """Return a full passage with vocabulary annotations."""
    user = await _resolve_user(db, auth)

    passage = await passage_service.get_passage(db, user.id, passage_id)
    if passage is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "PASSAGE_NOT_FOUND",
                    "message": "Passage not found.",
                    "details": {},
                }
            },
        )

    return PassageResponse.model_validate(passage)


# ---------------------------------------------------------------------------
# PATCH /v1/passages/{passage_id} — Update reading progress
# ---------------------------------------------------------------------------


@router.patch("/{passage_id}", response_model=PassageResponse)
async def update_passage(
    passage_id: uuid.UUID,
    body: PassageUpdateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PassageResponse:
    """Update reading progress or bookmark position on a passage."""
    user = await _resolve_user(db, auth)

    passage = await passage_service.update_passage(
        db,
        user.id,
        passage_id,
        reading_progress=body.reading_progress,
        bookmark_position=body.bookmark_position,
    )
    if passage is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "PASSAGE_NOT_FOUND",
                    "message": "Passage not found.",
                    "details": {},
                }
            },
        )

    return PassageResponse.model_validate(passage)


# ---------------------------------------------------------------------------
# DELETE /v1/passages/{passage_id} — Soft delete
# ---------------------------------------------------------------------------


@router.delete("/{passage_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_passage(
    passage_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> None:
    """Soft-delete a passage."""
    user = await _resolve_user(db, auth)

    deleted = await passage_service.delete_passage(db, user.id, passage_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "PASSAGE_NOT_FOUND",
                    "message": "Passage not found.",
                    "details": {},
                }
            },
        )
