"""Business logic for vocabulary items, definitions, and translations."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

import structlog
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models.vocabulary import VocabularyEncounter, VocabularyItem
from app.services import ai_service, dictionary_service

if TYPE_CHECKING:
    import uuid

    from redis.asyncio import Redis
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.enums import SourceType

logger = structlog.stdlib.get_logger()

# Redis cache TTLs (seconds)
_DEFINE_CACHE_TTL = 30 * 24 * 60 * 60  # 30 days
_DICT_CACHE_TTL = 90 * 24 * 60 * 60  # 90 days (dictionary hits are stable)
_TRANSLATE_CACHE_TTL = 7 * 24 * 60 * 60  # 7 days


# ---------------------------------------------------------------------------
# Vocabulary CRUD
# ---------------------------------------------------------------------------


async def create_vocabulary_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    user_language_id: uuid.UUID,
    *,
    text: str,
    translation: str,
    language: str,
    type: str = "word",
    phonetic: str | None = None,
    word_type: str | None = None,
    definitions: list[dict[str, Any]] | None = None,
    example_sentence: str | None = None,
    source_type: SourceType | None = None,
    source_id: uuid.UUID | None = None,
    context_sentence: str | None = None,
) -> VocabularyItem:
    """Create a vocabulary item with an optional encounter record.

    If the word already exists for this user+language, raises ``IntegrityError``.
    When a matching dictionary entry exists, the item is linked to it and
    enriched with canonical definitions so that flashcard practice uses
    consistent data.
    """
    # Try to link to the canonical dictionary entry
    dict_entry = await dictionary_service.lookup_word(db, text, language)
    dict_entry_id = dict_entry.id if dict_entry else None

    # Enrich with dictionary data when available
    if dict_entry is not None:
        resp = dictionary_service.entry_to_define_response(dict_entry)
        if not phonetic and resp.get("phonetic"):
            phonetic = resp["phonetic"]
        if not word_type and resp.get("word_type"):
            word_type = resp["word_type"]
        if not definitions and resp.get("definitions"):
            definitions = resp["definitions"]
        if not example_sentence and resp.get("example_sentence"):
            example_sentence = resp["example_sentence"]

    item = VocabularyItem(
        user_id=user_id,
        user_language_id=user_language_id,
        language=language,
        type=type,
        text=text,
        translation=translation,
        phonetic=phonetic,
        word_type=word_type,
        definitions=definitions,
        example_sentence=example_sentence,
        dictionary_entry_id=dict_entry_id,
    )
    db.add(item)

    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise

    # Optionally create an encounter record
    if source_type and source_id and context_sentence:
        encounter = VocabularyEncounter(
            vocabulary_item_id=item.id,
            source_type=source_type,
            source_id=source_id,
            context_sentence=context_sentence,
        )
        db.add(encounter)
        await db.flush()

    await db.refresh(item, attribute_names=["encounters"])

    logger.info(
        "vocabulary_item_created",
        item_id=str(item.id),
        user_id=str(user_id),
        text=text,
    )
    return item


async def delete_vocabulary_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
) -> bool:
    """Delete a vocabulary item.  Returns ``False`` if not found/not owned."""
    stmt = select(VocabularyItem).where(
        VocabularyItem.id == item_id,
        VocabularyItem.user_id == user_id,
    )
    result = await db.execute(stmt)
    item = result.scalar_one_or_none()

    if item is None:
        return False

    await db.delete(item)
    await db.flush()
    return True


# ---------------------------------------------------------------------------
# Define (with Redis cache)
# ---------------------------------------------------------------------------


def _define_cache_key(word: str, language: str) -> str:
    """Build a Redis key for a cached word definition."""
    return f"define:{language}:{word.lower().strip()}"


async def define_word(
    redis: Redis,  # type: ignore[type-arg]
    word: str,
    language: str,
    context_sentence: str | None = None,
    db: AsyncSession | None = None,
) -> dict[str, Any]:
    """Look up a word definition using a 3-tier strategy.

    1. **Redis cache** -- instant hit for previously looked-up words.
    2. **Local dictionary** -- Wiktionary-sourced entries stored in Postgres.
       If the entry has multiple senses and a context sentence is provided,
       an LLM micro-call selects the best sense.
    3. **AI generation** -- falls back to a full LLM definition call.

    Dictionary results are cached with a longer TTL (90 days) since they are
    stable reference data.
    """
    cache_key = _define_cache_key(word, language)

    # --- Tier 1: Redis cache ---
    cached = await redis.get(cache_key)
    if cached:
        logger.debug("define_cache_hit", word=word, language=language)
        return json.loads(cached)

    # --- Tier 2: Local dictionary ---
    if db is not None:
        entry = await dictionary_service.lookup_word(db, word, language)
        if entry is not None:
            active_sense_id: int | None = None
            senses = entry.senses or []

            if len(senses) > 1 and context_sentence:
                active_sense_id = await dictionary_service.select_sense(
                    redis, word, language, context_sentence, senses
                )

            result = dictionary_service.entry_to_define_response(
                entry, active_sense_id
            )

            # Cache with a longer TTL for dictionary hits
            await redis.setex(
                cache_key, _DICT_CACHE_TTL, json.dumps(result)
            )
            logger.info(
                "define_dictionary_hit",
                word=word,
                language=language,
                sense_id=active_sense_id,
            )
            return result

    # --- Tier 3: AI generation fallback ---
    result = await ai_service.define_word(word, language, context_sentence)

    # Cache the AI result with the standard TTL
    await redis.setex(cache_key, _DEFINE_CACHE_TTL, json.dumps(result))
    logger.info("define_ai_fallback", word=word, language=language)

    return result


# ---------------------------------------------------------------------------
# Translate (with Redis cache)
# ---------------------------------------------------------------------------


def _translate_cache_key(text: str, source_language: str, target_language: str) -> str:
    """Build a Redis key for a cached translation."""
    normalized = text.lower().strip()
    return f"translate:{source_language}:{target_language}:{normalized}"


async def translate_phrase(
    redis: Redis,  # type: ignore[type-arg]
    text: str,
    source_language: str,
    target_language: str,
    context: str | None = None,
) -> dict[str, Any]:
    """Translate a phrase, using Redis cache when available."""
    cache_key = _translate_cache_key(text, source_language, target_language)

    # Check cache
    cached = await redis.get(cache_key)
    if cached:
        logger.debug("translate_cache_hit", text=text[:50])
        return json.loads(cached)

    # Call AI service
    result = await ai_service.translate_phrase(
        text, source_language, target_language, context
    )

    # Cache the result
    await redis.setex(cache_key, _TRANSLATE_CACHE_TTL, json.dumps(result))
    logger.info("translate_cache_set", text=text[:50])

    return result
