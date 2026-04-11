"""Endpoints for vocabulary definitions, translations, and management."""

from __future__ import annotations

import uuid  # noqa: TC003
from typing import TYPE_CHECKING

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.core.redis import get_redis
from app.middleware.rate_limit import rate_limit_ai, rate_limit_default
from app.middleware.usage_meter import increment_translations_used
from app.schemas.vocabulary import (
    DefineRequest,
    DefineResponse,
    DefinitionEntry,
    TranslateRequest,
    TranslateResponse,
    VocabularyItemCreate,
    VocabularyItemResponse,
)
from app.services import vocabulary_service
from app.services.user_service import get_or_create_usage_meter, get_or_create_user

if TYPE_CHECKING:
    from redis.asyncio import Redis
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()

router = APIRouter(prefix="/vocabulary", tags=["vocabulary"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up (or create) the DB user for the authenticated JWT subject."""
    return await get_or_create_user(db, auth.sub, auth.email)


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/define — Word definition
# ---------------------------------------------------------------------------


@router.post("/define", response_model=DefineResponse)
async def define_word(
    body: DefineRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    redis: Redis = Depends(get_redis),  # type: ignore[type-arg]
    _rate: None = Depends(rate_limit_ai),
) -> DefineResponse:
    """Look up a word definition.

    Checks Redis cache first; falls back to the AI service and caches
    the result for 30 days.
    """
    # Auth check only (no usage limit for definitions)
    await _resolve_user(db, auth)

    result = await vocabulary_service.define_word(
        redis, body.word, body.language, body.context_sentence, db=db
    )

    # Normalise definitions into the response schema
    raw_defs = result.get("definitions", [])
    definitions = [
        DefinitionEntry(
            definition=d.get("definition", ""),
            example=d.get("example", ""),
            meaning=d.get("meaning", ""),
        )
        for d in raw_defs
    ]

    return DefineResponse(
        word=result.get("word", body.word),
        phonetic=result.get("phonetic"),
        word_type=result.get("word_type"),
        definitions=definitions,
        example_sentence=result.get("example_sentence"),
    )


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/translate — Phrase translation
# ---------------------------------------------------------------------------


@router.post("/translate", response_model=TranslateResponse)
async def translate_phrase(
    body: TranslateRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    redis: Redis = Depends(get_redis),  # type: ignore[type-arg]
    _rate: None = Depends(rate_limit_ai),
) -> TranslateResponse:
    """Translate a phrase or sentence.

    Checks Redis cache first; falls back to the AI service and caches
    the result for 7 days.  Increments the user's translation usage counter.
    """
    user = await _resolve_user(db, auth)

    # Check usage limit
    from app.middleware.usage_meter import _get_limit

    meter = await get_or_create_usage_meter(db, user.id, user.subscription_tier)
    limit = _get_limit(user.subscription_tier, "translations_used")
    if meter.translations_used >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": {
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "message": (
                        "Monthly translation limit reached. "
                        "Upgrade to Fluency for unlimited translations."
                    ),
                    "details": {
                        "limit": limit,
                        "used": meter.translations_used,
                        "resource": "translations",
                    },
                }
            },
        )

    result = await vocabulary_service.translate_phrase(
        redis, body.text, body.source_language, body.target_language, body.context
    )

    # Increment usage counter
    await increment_translations_used(db, user.id, user.subscription_tier)

    return TranslateResponse(
        text=result.get("text", body.text),
        translation=result.get("translation", ""),
    )


# ---------------------------------------------------------------------------
# POST /v1/vocabulary — Create vocabulary item
# ---------------------------------------------------------------------------


@router.post("", response_model=VocabularyItemResponse, status_code=201)
async def create_vocabulary_item(
    body: VocabularyItemCreate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> VocabularyItemResponse:
    """Add a word, phrase, or sentence to the user's vocabulary bank."""
    user = await _resolve_user(db, auth)

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

    try:
        item = await vocabulary_service.create_vocabulary_item(
            db,
            user.id,
            active_lang.id,
            text=body.text,
            translation=body.translation,
            language=body.language,
            type=body.type.value,
            phonetic=body.phonetic,
            word_type=body.word_type,
            definitions=body.definitions,
            example_sentence=body.example_sentence,
            source_type=body.source_type,
            source_id=body.source_id,
            context_sentence=body.context_sentence,
        )
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": {
                    "code": "VOCABULARY_EXISTS",
                    "message": (f"'{body.text}' is already in your vocabulary bank."),
                    "details": {"text": body.text},
                }
            },
        ) from exc

    return VocabularyItemResponse.model_validate(item)


# ---------------------------------------------------------------------------
# DELETE /v1/vocabulary/{item_id} — Remove vocabulary item
# ---------------------------------------------------------------------------


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vocabulary_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> None:
    """Remove a vocabulary item from the user's language bank."""
    user = await _resolve_user(db, auth)

    deleted = await vocabulary_service.delete_vocabulary_item(db, user.id, item_id)
    if not deleted:
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
