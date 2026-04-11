"""Endpoints for flashcard review, study sessions, vocabulary management, and stats."""

from __future__ import annotations

import uuid  # noqa: TC003
from typing import TYPE_CHECKING

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.core.redis import get_redis
from app.middleware.rate_limit import rate_limit_default
from app.models.enums import (
    CardTypeFilter,
    StudyMode,
    VocabularyStatus,
    VocabularyType,
)
from app.schemas.flashcard import (
    FlashcardCardResponse,
    FlashcardDueCountResponse,
    FlashcardDueResponse,
    FlashcardReviewRequest,
    FlashcardReviewResponse,
    FlashcardStatsResponse,
    PaginatedStudySessionsResponse,
    PaginatedVocabularyResponse,
    SessionReviewCardResponse,
    StudySessionCompleteRequest,
    StudySessionCreate,
    StudySessionDetailResponse,
    StudySessionResponse,
    VocabularyBatchCreateRequest,
    VocabularyBatchCreateResponse,
    VocabularyListItem,
    VocabularyStatsResponse,
    VocabularyUpdateRequest,
)
from app.schemas.vocabulary import (
    VocabularyEncounterResponse,
    VocabularyItemResponse,
)
from app.services import flashcard_service
from app.services.user_service import get_or_create_user

if TYPE_CHECKING:
    from redis.asyncio import Redis
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()

router = APIRouter(tags=["flashcards"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up (or create) the DB user for the authenticated JWT subject."""
    return await get_or_create_user(db, auth.sub, auth.email)


def _require_active_language(user: User) -> tuple[str, uuid.UUID]:
    """Return (language_code, user_language_id) or raise 400."""
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
    return active_lang.target_language, active_lang.id


# ===========================================================================
# Vocabulary endpoints (enhanced)
# ===========================================================================


# ---------------------------------------------------------------------------
# GET /v1/vocabulary — List vocabulary items
# ---------------------------------------------------------------------------


@router.get("/vocabulary", response_model=PaginatedVocabularyResponse)
async def list_vocabulary(
    search: str | None = Query(default=None, max_length=255),
    type: VocabularyType | None = Query(default=None),
    status: VocabularyStatus | None = Query(default=None),
    language: str | None = Query(default=None, max_length=10),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PaginatedVocabularyResponse:
    """List vocabulary items with filtering and pagination."""
    user = await _resolve_user(db, auth)

    # Default to active language if not specified
    lang = language
    if lang is None:
        active = user.active_language
        if active:
            lang = active.target_language

    items, next_cursor = await flashcard_service.list_vocabulary(
        db,
        user.id,
        language=lang,
        search=search,
        type_filter=type,
        status_filter=status,
        cursor=cursor,
        limit=limit,
    )

    return PaginatedVocabularyResponse(
        items=[VocabularyListItem.model_validate(item) for item in items],
        next_cursor=next_cursor,
    )


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/stats — Aggregate vocabulary counts
# ---------------------------------------------------------------------------


@router.get("/vocabulary/stats", response_model=VocabularyStatsResponse)
async def get_vocabulary_stats(
    language: str | None = Query(default=None, max_length=10),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> VocabularyStatsResponse:
    """Get aggregate vocabulary statistics."""
    user = await _resolve_user(db, auth)

    lang = language
    if lang is None:
        active = user.active_language
        if active:
            lang = active.target_language

    stats = await flashcard_service.get_vocabulary_stats(db, user.id, lang)
    return VocabularyStatsResponse(**stats)


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/{item_id} — Full vocabulary item detail
# ---------------------------------------------------------------------------


@router.get("/vocabulary/{item_id}", response_model=VocabularyItemResponse)
async def get_vocabulary_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> VocabularyItemResponse:
    """Get full detail for a vocabulary item including SM-2 stats."""
    user = await _resolve_user(db, auth)

    item = await flashcard_service.get_vocabulary_item(db, user.id, item_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "VOCABULARY_NOT_FOUND",
                    "message": "Vocabulary item not found.",
                    "details": {},
                }
            },
        )

    return VocabularyItemResponse.model_validate(item)


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/batch — Batch create vocabulary items
# ---------------------------------------------------------------------------


@router.post(
    "/vocabulary/batch",
    response_model=VocabularyBatchCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def batch_create_vocabulary(
    body: VocabularyBatchCreateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> VocabularyBatchCreateResponse:
    """Batch create vocabulary items, skipping duplicates."""
    user = await _resolve_user(db, auth)
    _, user_language_id = _require_active_language(user)

    items_data = [item.model_dump() for item in body.items]
    created, skipped = await flashcard_service.batch_create_vocabulary(
        db, user.id, user_language_id, items_data
    )

    return VocabularyBatchCreateResponse(
        created=len(created),
        skipped=skipped,
        items=[VocabularyListItem.model_validate(item) for item in created],
    )


# ---------------------------------------------------------------------------
# PATCH /v1/vocabulary/{item_id} — Update vocabulary item
# ---------------------------------------------------------------------------


@router.patch("/vocabulary/{item_id}", response_model=VocabularyItemResponse)
async def update_vocabulary_item(
    item_id: uuid.UUID,
    body: VocabularyUpdateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> VocabularyItemResponse:
    """Update a vocabulary item's status, content, or reset SM-2 data."""
    user = await _resolve_user(db, auth)

    update_data = body.model_dump(exclude_unset=True)
    item = await flashcard_service.update_vocabulary_item(
        db,
        user.id,
        item_id,
        **update_data,
    )
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "VOCABULARY_NOT_FOUND",
                    "message": "Vocabulary item not found.",
                    "details": {},
                }
            },
        )

    return VocabularyItemResponse.model_validate(item)


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/{item_id}/encounters — Encounter history
# ---------------------------------------------------------------------------


@router.get(
    "/vocabulary/{item_id}/encounters",
    response_model=list[VocabularyEncounterResponse],
)
async def get_vocabulary_encounters(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> list[VocabularyEncounterResponse]:
    """Get encounter history for a vocabulary item."""
    user = await _resolve_user(db, auth)

    encounters = await flashcard_service.get_encounter_history(db, user.id, item_id)
    if not encounters:
        # Check if item exists but has no encounters vs item not found
        item = await flashcard_service.get_vocabulary_item(db, user.id, item_id)
        if item is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "VOCABULARY_NOT_FOUND",
                        "message": "Vocabulary item not found.",
                        "details": {},
                    }
                },
            )

    return [VocabularyEncounterResponse.model_validate(e) for e in encounters]


# ===========================================================================
# Flashcard review endpoints
# ===========================================================================


# ---------------------------------------------------------------------------
# GET /v1/flashcards/due — Get cards due for review
# ---------------------------------------------------------------------------


@router.get("/flashcards/due")
async def get_due_cards(
    mode: StudyMode = Query(default=StudyMode.DAILY),
    type: CardTypeFilter | None = Query(default=None),
    count_only: bool = Query(default=False),
    limit: int = Query(default=25, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> FlashcardDueResponse | FlashcardDueCountResponse:
    """Get vocabulary items due for flashcard review.

    Supports five modes: daily, hardest, new, ahead, random.
    """
    user = await _resolve_user(db, auth)
    language, _ = _require_active_language(user)

    if count_only:
        count = await flashcard_service.get_due_cards(
            db, user.id, language, mode, type, limit, count_only=True
        )
        return FlashcardDueCountResponse(count=count)

    items = await flashcard_service.get_due_cards(
        db, user.id, language, mode, type, limit
    )
    return FlashcardDueResponse(
        items=[FlashcardCardResponse.model_validate(item) for item in items],
        total_due=len(items),
    )


# ---------------------------------------------------------------------------
# POST /v1/flashcards/{item_id}/review — Submit a card review
# ---------------------------------------------------------------------------


@router.post("/flashcards/{item_id}/review", response_model=FlashcardReviewResponse)
async def review_flashcard(
    item_id: uuid.UUID,
    body: FlashcardReviewRequest,
    session_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> FlashcardReviewResponse:
    """Submit a flashcard review and update SM-2 spaced repetition data."""
    user = await _resolve_user(db, auth)

    try:
        item, review_event = await flashcard_service.process_review(
            db,
            user.id,
            item_id,
            quality=body.quality,
            response_time_ms=body.response_time_ms,
            session_id=session_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "VOCABULARY_NOT_FOUND",
                    "message": "Vocabulary item not found.",
                    "details": {},
                }
            },
        ) from exc

    return FlashcardReviewResponse(
        id=item.id,
        text=item.text,
        translation=item.translation,
        status=item.status,
        ease_factor=item.ease_factor,
        interval=item.interval,
        repetitions=item.repetitions,
        next_review_date=item.next_review_date,
        times_reviewed=item.times_reviewed,
        times_correct=item.times_correct,
        last_reviewed_at=item.last_reviewed_at,
        review_event_id=review_event.id,
    )


# ===========================================================================
# Study session endpoints
# ===========================================================================


# ---------------------------------------------------------------------------
# POST /v1/flashcards/sessions — Create study session
# ---------------------------------------------------------------------------


@router.post(
    "/flashcards/sessions",
    response_model=StudySessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_study_session(
    body: StudySessionCreate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> StudySessionResponse:
    """Create a new flashcard study session."""
    user = await _resolve_user(db, auth)
    language, _ = _require_active_language(user)

    session = await flashcard_service.create_study_session(
        db,
        user.id,
        language,
        mode=body.mode,
        card_limit=body.card_limit,
        card_type_filter=body.card_type_filter,
    )

    return StudySessionResponse.model_validate(session)


# ---------------------------------------------------------------------------
# GET /v1/flashcards/sessions — List past sessions
# ---------------------------------------------------------------------------


@router.get("/flashcards/sessions", response_model=PaginatedStudySessionsResponse)
async def list_study_sessions(
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PaginatedStudySessionsResponse:
    """List past study sessions with pagination."""
    user = await _resolve_user(db, auth)

    sessions, next_cursor = await flashcard_service.list_study_sessions(
        db, user.id, cursor=cursor, limit=limit
    )

    return PaginatedStudySessionsResponse(
        items=[StudySessionResponse.model_validate(s) for s in sessions],
        next_cursor=next_cursor,
    )


# ---------------------------------------------------------------------------
# GET /v1/flashcards/sessions/{session_id} — Session detail
# ---------------------------------------------------------------------------


@router.get(
    "/flashcards/sessions/{session_id}",
    response_model=StudySessionDetailResponse,
)
async def get_study_session(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> StudySessionDetailResponse:
    """Get full study session detail with per-card breakdown."""
    user = await _resolve_user(db, auth)

    session = await flashcard_service.get_study_session(db, user.id, session_id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "SESSION_NOT_FOUND",
                    "message": "Study session not found.",
                    "details": {},
                }
            },
        )

    # Build per-card breakdown
    cards = []
    for sr in sorted(session.session_reviews, key=lambda r: r.card_order):
        review = sr.review_event
        vocab = sr.vocabulary_item
        cards.append(
            SessionReviewCardResponse(
                card_order=sr.card_order,
                vocabulary_item_id=sr.vocabulary_item_id,
                text=vocab.text if vocab else "",
                translation=vocab.translation if vocab else "",
                quality=review.quality if review else 0,
                previous_ease_factor=review.previous_ease_factor if review else 0,
                new_ease_factor=review.new_ease_factor if review else 0,
                previous_interval=review.previous_interval if review else 0,
                new_interval=review.new_interval if review else 0,
                response_time_ms=review.response_time_ms if review else None,
            )
        )

    return StudySessionDetailResponse(
        id=session.id,
        language=session.language,
        mode=session.mode,
        card_limit=session.card_limit,
        card_type_filter=session.card_type_filter,
        total_cards=session.total_cards,
        correct_count=session.correct_count,
        incorrect_count=session.incorrect_count,
        duration_seconds=session.duration_seconds,
        completed_at=session.completed_at,
        created_at=session.created_at,
        updated_at=session.updated_at,
        cards=cards,
    )


# ---------------------------------------------------------------------------
# PATCH /v1/flashcards/sessions/{session_id} — Complete session
# ---------------------------------------------------------------------------


@router.patch(
    "/flashcards/sessions/{session_id}",
    response_model=StudySessionResponse,
)
async def complete_study_session(
    session_id: uuid.UUID,
    body: StudySessionCompleteRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> StudySessionResponse:
    """Complete a study session by setting its duration and completed_at."""
    user = await _resolve_user(db, auth)

    session = await flashcard_service.complete_study_session(
        db, user.id, session_id, body.duration_seconds
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "SESSION_NOT_FOUND",
                    "message": "Study session not found.",
                    "details": {},
                }
            },
        )

    return StudySessionResponse.model_validate(session)


# ---------------------------------------------------------------------------
# POST /v1/flashcards/sessions/{session_id}/restudy — Restudy missed cards
# ---------------------------------------------------------------------------


@router.post(
    "/flashcards/sessions/{session_id}/restudy",
    response_model=StudySessionDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
async def restudy_session(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> StudySessionDetailResponse:
    """Create a new study session from missed cards in a previous session."""
    user = await _resolve_user(db, auth)

    result = await flashcard_service.create_restudy_session(db, user.id, session_id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "NO_MISSED_CARDS",
                    "message": ("Session not found or has no missed cards to restudy."),
                    "details": {},
                }
            },
        )

    new_session, missed_items = result

    return StudySessionDetailResponse(
        id=new_session.id,
        language=new_session.language,
        mode=new_session.mode,
        card_limit=new_session.card_limit,
        card_type_filter=new_session.card_type_filter,
        total_cards=new_session.total_cards,
        correct_count=new_session.correct_count,
        incorrect_count=new_session.incorrect_count,
        duration_seconds=new_session.duration_seconds,
        completed_at=new_session.completed_at,
        created_at=new_session.created_at,
        updated_at=new_session.updated_at,
        cards=[],
    )


# ===========================================================================
# Stats endpoint
# ===========================================================================


# ---------------------------------------------------------------------------
# GET /v1/flashcards/stats — Full flashcard statistics
# ---------------------------------------------------------------------------


@router.get("/flashcards/stats", response_model=FlashcardStatsResponse)
async def get_flashcard_stats(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    redis: Redis = Depends(get_redis),  # type: ignore[type-arg]
    _rate: None = Depends(rate_limit_default),
) -> FlashcardStatsResponse:
    """Get comprehensive flashcard statistics (Redis cached 1h)."""
    user = await _resolve_user(db, auth)
    language, _ = _require_active_language(user)

    stats = await flashcard_service.get_flashcard_stats(db, redis, user.id, language)
    return FlashcardStatsResponse(**stats)
