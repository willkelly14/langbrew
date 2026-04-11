"""Dictionary lookup service — offline-first word definitions from Wiktionary data."""

from __future__ import annotations

import hashlib
from typing import TYPE_CHECKING, Any

import structlog
from sqlalchemy import select

from app.models.dictionary import DictionaryEntry, DictionaryForm
from app.services import ai_service

if TYPE_CHECKING:
    from redis.asyncio import Redis
    from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.stdlib.get_logger()

# Redis TTL for sense-selection cache (24 hours)
_SENSE_CACHE_TTL = 24 * 60 * 60


# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------


async def lookup_word(
    db: AsyncSession,
    word: str,
    language: str,
) -> DictionaryEntry | None:
    """Look up a word in the local dictionary.

    Tries a direct ``dictionary_entries`` lookup by lemma first (preferring
    nouns over other POS), then falls back to ``dictionary_forms`` for
    inflected forms like "corriendo" -> "correr".
    """
    normalized = word.lower().strip()
    if not normalized:
        return None

    # 1. Direct lemma lookup (prefer noun > adj > verb > other)
    entry_stmt = (
        select(DictionaryEntry)
        .where(
            DictionaryEntry.language == language,
            DictionaryEntry.lemma == normalized,
        )
    )
    entry_result = await db.execute(entry_stmt)
    entries = list(entry_result.scalars().all())

    if entries:
        # Prefer noun, then adjective, then first match
        pos_priority = {"noun": 0, "adjective": 1, "verb": 2}
        entries.sort(key=lambda e: pos_priority.get(e.word_type, 9))
        entry = entries[0]
        logger.debug(
            "dictionary_lookup_direct",
            word=normalized,
            lemma=entry.lemma,
            word_type=entry.word_type,
            language=language,
        )
        return entry

    # 2. Check inflected forms table
    form_stmt = (
        select(DictionaryForm)
        .where(
            DictionaryForm.language == language,
            DictionaryForm.surface_form == normalized,
        )
        .limit(1)
    )
    form_result = await db.execute(form_stmt)
    form = form_result.scalar_one_or_none()

    if form is not None:
        entry_stmt = select(DictionaryEntry).where(
            DictionaryEntry.id == form.dictionary_entry_id,
        )
        entry_result = await db.execute(entry_stmt)
        entry = entry_result.scalar_one_or_none()
        if entry is not None:
            logger.debug(
                "dictionary_lookup_via_form",
                word=normalized,
                lemma=entry.lemma,
                language=language,
            )
            return entry

    logger.debug(
        "dictionary_lookup_miss",
        word=normalized,
        language=language,
    )
    return None


# ---------------------------------------------------------------------------
# Sense selection (LLM-assisted disambiguation)
# ---------------------------------------------------------------------------


def _sense_cache_key(word: str, language: str, context_sentence: str) -> str:
    """Build a Redis key for a cached sense selection."""
    ctx_hash = hashlib.sha256(context_sentence.encode()).hexdigest()[:16]
    return f"sense:{language}:{word.lower().strip()}:{ctx_hash}"


async def select_sense(
    redis: Redis,  # type: ignore[type-arg]
    word: str,
    language: str,
    context_sentence: str,
    senses: list[dict[str, Any]],
) -> int | None:
    """Use a minimal LLM call to pick the right dictionary sense in context.

    Only called when ``len(senses) > 1`` and a context sentence is provided.
    Results are cached in Redis for 24 hours.

    Returns the ``sense_id`` (int) of the best-matching sense, or ``None`` on
    failure.
    """
    cache_key = _sense_cache_key(word, language, context_sentence)

    # Check cache
    cached = await redis.get(cache_key)
    if cached is not None:
        try:
            return int(cached)
        except (ValueError, TypeError):
            pass

    # Build prompt and call LLM
    prompt = ai_service.build_sense_selection_prompt(
        word, language, context_sentence, senses
    )
    try:
        result = await ai_service.call_openrouter_raw(prompt, max_tokens=8)
        # The LLM should reply with just a number
        sense_id = int(result.strip())
    except (ValueError, TypeError, KeyError, Exception):
        logger.warning(
            "sense_selection_failed",
            word=word,
            language=language,
        )
        return None

    # Validate the returned sense_id exists
    valid_ids = {s.get("sense_id") for s in senses}
    if sense_id not in valid_ids:
        logger.warning(
            "sense_selection_invalid_id",
            word=word,
            returned=sense_id,
            valid_ids=valid_ids,
        )
        return None

    # Cache the result
    await redis.setex(cache_key, _SENSE_CACHE_TTL, str(sense_id))
    logger.debug(
        "sense_selected",
        word=word,
        sense_id=sense_id,
        language=language,
    )
    return sense_id


# ---------------------------------------------------------------------------
# Response formatting
# ---------------------------------------------------------------------------


def entry_to_define_response(
    entry: DictionaryEntry,
    active_sense_id: int | None = None,
) -> dict[str, Any]:
    """Convert a ``DictionaryEntry`` to the shape expected by ``DefineResponse``.

    Parameters
    ----------
    entry:
        The dictionary entry to format.
    active_sense_id:
        If provided, the sense with this id is placed first in the
        definitions list.

    Returns
    -------
    dict
        Keys: word, phonetic, word_type, definitions, example_sentence, source.
    """
    definitions: list[dict[str, str]] = []
    first_example: str | None = None

    senses = entry.senses or []

    # Sort so the active sense comes first
    if active_sense_id is not None:
        senses = sorted(
            senses,
            key=lambda s: (0 if s.get("sense_id") == active_sense_id else 1),
        )

    for sense in senses:
        definitions.append(
            {
                "definition": sense.get("definition", ""),
                "example": sense.get("example", ""),
                "meaning": sense.get("translation", ""),
            }
        )
        if first_example is None and sense.get("example"):
            first_example = sense["example"]

    return {
        "word": entry.display_form or entry.lemma,
        "phonetic": entry.phonetic,
        "word_type": entry.word_type,
        "definitions": definitions,
        "example_sentence": first_example,
        "source": "dictionary",
    }
