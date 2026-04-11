"""CLI script to import Wiktionary dictionary data from Kaikki JSONL dumps.

Usage::

    python -m app.scripts.import_dictionary \
        --language Spanish \
        --file data/kaikki-spanish.jsonl \
        --frequency-file data/spanish-frequency.csv \
        --batch-size 1000

The Kaikki JSONL format (from https://kaikki.org) has one JSON object per
line with fields like::

    {
      "word": "correr",
      "pos": "verb",
      "senses": [{"glosses": ["to run"], "examples": [...]}],
      "sounds": [{"ipa": "/koˈreɾ/"}],
      "forms": [{"form": "corriendo", "tags": ["gerund"]}]
    }

The optional frequency file is a CSV with columns ``word,rank`` (no header).
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import sys
import time
from pathlib import Path
from typing import Any

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings

logger = structlog.stdlib.get_logger()

# ---------------------------------------------------------------------------
# POS mapping
# ---------------------------------------------------------------------------

_POS_MAP: dict[str, str] = {
    "noun": "noun",
    "verb": "verb",
    "adj": "adjective",
    "adv": "adverb",
    "pron": "pronoun",
    "prep": "preposition",
    "conj": "conjunction",
    "det": "determiner",
    "intj": "interjection",
    "num": "numeral",
    "particle": "particle",
    "phrase": "phrase",
    "name": "proper noun",
    "prefix": "prefix",
    "suffix": "suffix",
    # Common Kaikki variations
    "adjective": "adjective",
    "adverb": "adverb",
    "pronoun": "pronoun",
    "preposition": "preposition",
    "conjunction": "conjunction",
    "determiner": "determiner",
    "interjection": "interjection",
    "numeral": "numeral",
    "proper noun": "proper noun",
}

# ---------------------------------------------------------------------------
# CEFR estimation from frequency rank
# ---------------------------------------------------------------------------

_CEFR_BANDS: list[tuple[int, str]] = [
    (500, "A1"),
    (1500, "A2"),
    (3500, "B1"),
    (7000, "B2"),
]


def _rank_to_cefr(rank: int) -> str:
    """Map a frequency rank to an estimated CEFR level."""
    for threshold, level in _CEFR_BANDS:
        if rank <= threshold:
            return level
    return "C1"


# ---------------------------------------------------------------------------
# Kaikki entry parsing
# ---------------------------------------------------------------------------


def _extract_ipa(sounds: list[dict[str, Any]]) -> str | None:
    """Pick the first IPA transcription from the sounds array."""
    for sound in sounds:
        ipa = sound.get("ipa")
        if ipa:
            return ipa
    return None


def _extract_senses(
    raw_senses: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Convert Kaikki senses to our internal format.

    Each output sense has: sense_id, definition, translation, example,
    example_translation, tags.
    """
    result: list[dict[str, Any]] = []
    for idx, sense in enumerate(raw_senses):
        glosses = sense.get("glosses", [])
        if not glosses:
            continue

        # The first gloss is the primary definition / translation
        definition = glosses[0]

        # Some Kaikki entries have a "raw_glosses" field with richer text
        raw_glosses = sense.get("raw_glosses", [])
        if raw_glosses and len(raw_glosses[0]) > len(definition):
            definition = raw_glosses[0]

        # Extract example sentences
        examples = sense.get("examples", [])
        example_text = ""
        example_translation = ""
        if examples:
            first_example = examples[0]
            if isinstance(first_example, dict):
                example_text = first_example.get("text", "")
                example_translation = first_example.get("english", "")
            elif isinstance(first_example, str):
                example_text = first_example

        # Tags
        tags = sense.get("tags", [])

        result.append(
            {
                "sense_id": idx,
                "definition": definition,
                "translation": definition,  # For Kaikki English-gloss dumps
                "example": example_text,
                "example_translation": example_translation,
                "tags": tags,
            }
        )

    return result


def _extract_forms(
    raw_forms: list[dict[str, Any]],
    language: str,
    lemma: str,
    word_type: str,
) -> list[dict[str, str]]:
    """Extract inflected forms from the Kaikki forms array.

    Returns a list of dicts with: language, surface_form, lemma, word_type.
    Filters out the lemma itself and empty forms.
    """
    seen: set[str] = set()
    result: list[dict[str, str]] = []
    lemma_lower = lemma.lower()

    for form_obj in raw_forms:
        surface = form_obj.get("form", "").strip()
        if not surface:
            continue
        surface_lower = surface.lower()
        # Skip the lemma itself and duplicates
        if surface_lower == lemma_lower or surface_lower in seen:
            continue
        seen.add(surface_lower)

        result.append(
            {
                "language": language,
                "surface_form": surface_lower,
                "lemma": lemma_lower,
                "word_type": word_type,
                "de_language": language,
                "de_lemma": lemma_lower,
                "de_word_type": word_type,
            }
        )

    return result


def parse_kaikki_line(
    line: str,
    language: str,
    frequency_map: dict[str, int] | None = None,
) -> tuple[dict[str, Any] | None, list[dict[str, str]]]:
    """Parse a single Kaikki JSONL line into an entry dict and forms list.

    Returns ``(None, [])`` if the line should be skipped.
    """
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return None, []

    word = obj.get("word", "").strip()
    pos = obj.get("pos", "").lower()
    if not word or not pos:
        return None, []

    word_type = _POS_MAP.get(pos)
    if word_type is None:
        return None, []

    raw_senses = obj.get("senses", [])
    senses = _extract_senses(raw_senses)
    if not senses:
        return None, []

    lemma = word.lower()

    # Phonetic
    phonetic = _extract_ipa(obj.get("sounds", []))

    # Frequency / CEFR
    frequency_rank: int | None = None
    cefr_estimate: str | None = None
    if frequency_map and lemma in frequency_map:
        frequency_rank = frequency_map[lemma]
        cefr_estimate = _rank_to_cefr(frequency_rank)

    # Etymology (Kaikki stores it as "etymology_text")
    etymology = obj.get("etymology_text")

    entry_dict: dict[str, Any] = {
        "language": language,
        "lemma": lemma,
        "display_form": word,
        "word_type": word_type,
        "phonetic": phonetic,
        "frequency_rank": frequency_rank,
        "cefr_estimate": cefr_estimate,
        "senses": json.dumps(senses),
        "etymology": etymology,
        "synonyms": json.dumps(
            [
                s.get("word", "")
                for syn_list in (
                    sense.get("synonyms", []) for sense in raw_senses
                )
                for s in (syn_list if isinstance(syn_list, list) else [])
                if s.get("word")
            ]
            or None
        ),
        "source": "wiktionary",
        "source_version": None,
    }

    # Forms
    raw_forms = obj.get("forms", [])
    forms = _extract_forms(raw_forms, language, lemma, word_type)

    return entry_dict, forms


# ---------------------------------------------------------------------------
# Frequency file loader
# ---------------------------------------------------------------------------


def load_frequency_file(path: str) -> dict[str, int]:
    """Load a CSV frequency file (word,rank) into a lookup dict.

    The file should have no header row. Each row is ``word,rank``.
    """
    freq_map: dict[str, int] = {}
    with open(path, encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 2:
                continue
            word = row[0].strip().lower()
            try:
                rank = int(row[1].strip())
            except ValueError:
                continue
            if word and rank > 0:
                freq_map[word] = rank
    return freq_map


# ---------------------------------------------------------------------------
# Database upsert helpers
# ---------------------------------------------------------------------------

_UPSERT_ENTRIES_SQL = """
INSERT INTO dictionary_entries (
    id, language, lemma, display_form, word_type, phonetic,
    frequency_rank, cefr_estimate, senses, etymology, synonyms,
    source, source_version, created_at, updated_at
)
VALUES (
    gen_random_uuid(), :language, :lemma, :display_form, :word_type, :phonetic,
    :frequency_rank, :cefr_estimate, CAST(:senses AS jsonb), :etymology, CAST(:synonyms AS jsonb),
    :source, :source_version, now(), now()
)
ON CONFLICT ON CONSTRAINT uq_dictionary_lang_lemma_word_type
DO UPDATE SET
    display_form = EXCLUDED.display_form,
    phonetic = COALESCE(EXCLUDED.phonetic, dictionary_entries.phonetic),
    frequency_rank = COALESCE(
        EXCLUDED.frequency_rank, dictionary_entries.frequency_rank
    ),
    cefr_estimate = COALESCE(EXCLUDED.cefr_estimate, dictionary_entries.cefr_estimate),
    senses = EXCLUDED.senses,
    etymology = COALESCE(EXCLUDED.etymology, dictionary_entries.etymology),
    synonyms = COALESCE(EXCLUDED.synonyms, dictionary_entries.synonyms),
    source = EXCLUDED.source,
    source_version = EXCLUDED.source_version,
    updated_at = now()
"""

_UPSERT_FORMS_SQL = """
INSERT INTO dictionary_forms (
    id, language, surface_form, lemma, word_type, dictionary_entry_id
)
SELECT
    gen_random_uuid(),
    CAST(:language AS varchar(10)),
    CAST(:surface_form AS varchar(255)),
    CAST(:lemma AS varchar(255)),
    CAST(:word_type AS varchar(64)),
    de.id
FROM dictionary_entries de
WHERE de.language = CAST(:de_language AS varchar(10))
  AND de.lemma = CAST(:de_lemma AS varchar(255))
  AND de.word_type = CAST(:de_word_type AS varchar(64))
LIMIT 1
ON CONFLICT ON CONSTRAINT uq_dictionary_form_lang_surface_word_type
DO UPDATE SET
    lemma = EXCLUDED.lemma,
    dictionary_entry_id = EXCLUDED.dictionary_entry_id
"""


async def _upsert_entries_batch(
    session: AsyncSession,
    entries: list[dict[str, Any]],
) -> None:
    """Bulk upsert a batch of dictionary entries."""
    if not entries:
        return
    await session.execute(text(_UPSERT_ENTRIES_SQL), entries)


async def _upsert_forms_batch(
    session: AsyncSession,
    forms: list[dict[str, str]],
) -> None:
    """Bulk upsert a batch of dictionary forms."""
    if not forms:
        return
    await session.execute(text(_UPSERT_FORMS_SQL), forms)


# ---------------------------------------------------------------------------
# Main import loop
# ---------------------------------------------------------------------------


async def run_import(
    file_path: str,
    language: str,
    frequency_file: str | None = None,
    batch_size: int = 1000,
) -> None:
    """Read a Kaikki JSONL file and bulk-upsert entries + forms."""
    logger.info(
        "import_started",
        file=file_path,
        language=language,
        frequency_file=frequency_file,
        batch_size=batch_size,
    )

    # Load frequency data
    frequency_map: dict[str, int] | None = None
    if frequency_file:
        frequency_map = load_frequency_file(frequency_file)
        logger.info("frequency_file_loaded", count=len(frequency_map))

    # Create a standalone engine (not the app engine) for the script
    engine = create_async_engine(
        settings.DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
    )
    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    total_entries = 0
    total_forms = 0
    skipped = 0
    start_time = time.monotonic()

    path = Path(file_path)
    if not path.exists():
        logger.error("file_not_found", file=file_path)
        sys.exit(1)

    # Collect all parsed data first, then insert in two passes
    # (entries first, then forms) to avoid deadlocks.
    all_entries: list[dict[str, Any]] = []
    all_forms: list[dict[str, str]] = []

    logger.info("parsing_file")
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue

            entry_dict, forms = parse_kaikki_line(
                line, language, frequency_map
            )
            if entry_dict is None:
                skipped += 1
                continue

            all_entries.append(entry_dict)
            all_forms.extend(forms)

            if line_no % 50000 == 0:
                logger.info("parsing_progress", lines=line_no)

    total_entries = len(all_entries)
    total_forms = len(all_forms)
    logger.info(
        "parsing_complete",
        entries=total_entries,
        forms=total_forms,
        skipped=skipped,
    )

    # Pass 1: Insert all entries
    logger.info("inserting_entries", total=total_entries)
    for i in range(0, total_entries, batch_size):
        batch = all_entries[i : i + batch_size]
        async with session_factory() as session:
            await _upsert_entries_batch(session, batch)
            await session.commit()
        if (i + batch_size) % 10000 < batch_size:
            elapsed = time.monotonic() - start_time
            logger.info(
                "entries_progress",
                done=min(i + batch_size, total_entries),
                total=total_entries,
                elapsed=f"{elapsed:.0f}s",
            )

    # Pass 2: Insert all forms (entries must exist first)
    logger.info("inserting_forms", total=total_forms)
    for i in range(0, total_forms, batch_size):
        batch = all_forms[i : i + batch_size]
        async with session_factory() as session:
            await _upsert_forms_batch(session, batch)
            await session.commit()
        if (i + batch_size) % 20000 < batch_size:
            elapsed = time.monotonic() - start_time
            logger.info(
                "forms_progress",
                done=min(i + batch_size, total_forms),
                total=total_forms,
                elapsed=f"{elapsed:.0f}s",
            )

    elapsed = time.monotonic() - start_time
    await engine.dispose()

    logger.info(
        "import_complete",
        entries=total_entries,
        forms=total_forms,
        skipped=skipped,
        elapsed=f"{elapsed:.1f}s",
    )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> None:
    """Parse CLI args and run the async import."""
    parser = argparse.ArgumentParser(
        description="Import Wiktionary dictionary data from Kaikki JSONL dumps.",
    )
    parser.add_argument(
        "--language",
        required=True,
        help="Target language name (e.g. Spanish, French, German).",
    )
    parser.add_argument(
        "--file",
        required=True,
        help="Path to the Kaikki JSONL dump file.",
    )
    parser.add_argument(
        "--frequency-file",
        default=None,
        help="Optional CSV file with word,rank frequency data.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1000,
        help="Number of entries per database batch (default: 1000).",
    )
    args = parser.parse_args()

    asyncio.run(
        run_import(
            file_path=args.file,
            language=args.language,
            frequency_file=args.frequency_file,
            batch_size=args.batch_size,
        )
    )


if __name__ == "__main__":
    main()
