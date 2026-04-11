"""Business logic for passage creation, retrieval, and management."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

import structlog
from sqlalchemy import select

from app.models.enums import CEFRLevel, PassageLength, PassageStyle
from app.models.passage import Passage
from app.models.passage_vocabulary import PassageVocabulary
from app.schemas.passage import PassageListItem
from app.services import dictionary_service

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.stdlib.get_logger()

# Excerpt length for list items
_EXCERPT_LENGTH = 200


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------


async def create_passage(
    db: AsyncSession,
    user_id: uuid.UUID,
    user_language_id: uuid.UUID,
    passage_data: dict[str, Any],
    vocabulary_data: list[dict[str, Any]],
    *,
    language: str,
    cefr_level: str,
    style: str | None = None,
    length: str | None = None,
) -> Passage:
    """Store a generated passage with its vocabulary annotations."""
    content = passage_data.get("content", "")
    word_count = len(content.split())
    # Estimate ~200 words per minute for reading
    estimated_minutes = max(1, round(word_count / 200))

    passage = Passage(
        user_id=user_id,
        user_language_id=user_language_id,
        title=passage_data.get("title", "Untitled"),
        content=content,
        language=language,
        cefr_level=CEFRLevel(cefr_level),
        topic=passage_data.get("topic", ""),
        word_count=word_count,
        estimated_minutes=estimated_minutes,
        is_generated=True,
        style=PassageStyle(style) if style else None,
        length=PassageLength(length) if length else None,
    )
    db.add(passage)
    await db.flush()

    # Create vocabulary annotations, enriching with dictionary data when available
    for vocab in vocabulary_data:
        word_text = vocab.get("word", "")
        definition = vocab.get("definition")
        translation = vocab.get("translation")
        phonetic = vocab.get("phonetic")
        word_type = vocab.get("word_type")
        example_sentence = vocab.get("example_sentence")
        dictionary_entry_id = None

        # Attempt dictionary enrichment
        if word_text:
            try:
                entry = await dictionary_service.lookup_word(
                    db, word_text, language
                )
                if entry is not None:
                    dictionary_entry_id = entry.id
                    # Use dictionary for phonetic and word_type (more
                    # reliable than AI), but keep the AI's definition
                    # and translation which are richer than Kaikki's
                    # brief English glosses.
                    if entry.phonetic:
                        phonetic = entry.phonetic
                    if entry.word_type:
                        word_type = entry.word_type
            except Exception:
                logger.debug(
                    "passage_vocab_dictionary_miss",
                    word=word_text,
                    language=language,
                )

        annotation = PassageVocabulary(
            passage_id=passage.id,
            word=word_text,
            start_index=vocab.get("start_index", 0),
            end_index=vocab.get("end_index", 0),
            definition=definition,
            translation=translation,
            phonetic=phonetic,
            word_type=word_type,
            example_sentence=example_sentence,
            dictionary_entry_id=dictionary_entry_id,
        )
        db.add(annotation)

    await db.flush()
    await db.refresh(passage, attribute_names=["vocabulary_annotations"])

    logger.info(
        "passage_created",
        passage_id=str(passage.id),
        user_id=str(user_id),
        word_count=word_count,
    )
    return passage


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------


async def list_passages(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    search: str | None = None,
    cefr_level: str | None = None,
    topic: str | None = None,
    is_generated: bool | None = None,
    sort_by: str = "date",
    sort_order: str = "desc",
    cursor: str | None = None,
    limit: int = 20,
) -> tuple[list[PassageListItem], str | None]:
    """Query passages with filters, sorting, and cursor-based pagination.

    Returns ``(items, next_cursor)``.
    """
    stmt = select(Passage).where(
        Passage.user_id == user_id,
        Passage.deleted_at.is_(None),
    )

    # Filters
    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(Passage.title.ilike(pattern) | Passage.content.ilike(pattern))
    if cefr_level:
        stmt = stmt.where(Passage.cefr_level == CEFRLevel(cefr_level))
    if topic:
        stmt = stmt.where(Passage.topic.ilike(f"%{topic}%"))
    if is_generated is not None:
        stmt = stmt.where(Passage.is_generated == is_generated)

    # Sorting
    sort_column = {
        "date": Passage.created_at,
        "difficulty": Passage.cefr_level,
        "topic": Passage.topic,
    }.get(sort_by, Passage.created_at)

    if sort_order == "asc":
        stmt = stmt.order_by(sort_column.asc(), Passage.id.asc())
    else:
        stmt = stmt.order_by(sort_column.desc(), Passage.id.desc())

    # Cursor-based pagination: cursor is the last passage id
    if cursor:
        try:
            cursor_uuid = uuid.UUID(cursor)
            # Look up the cursor passage to get its sort value
            cursor_stmt = select(Passage).where(Passage.id == cursor_uuid)
            cursor_result = await db.execute(cursor_stmt)
            cursor_passage = cursor_result.scalar_one_or_none()
            if cursor_passage:
                sort_attr = sort_by if sort_by != "date" else "created_at"
                cursor_val = getattr(
                    cursor_passage,
                    sort_attr,
                    cursor_passage.created_at,
                )
                if sort_order == "asc":
                    stmt = stmt.where(
                        (sort_column > cursor_val)
                        | ((sort_column == cursor_val) & (Passage.id > cursor_uuid))
                    )
                else:
                    stmt = stmt.where(
                        (sort_column < cursor_val)
                        | ((sort_column == cursor_val) & (Passage.id < cursor_uuid))
                    )
        except ValueError:
            pass  # Invalid cursor, ignore

    # Fetch one extra to determine if there's a next page
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    passages = list(result.scalars().all())

    next_cursor: str | None = None
    if len(passages) > limit:
        passages = passages[:limit]
        next_cursor = str(passages[-1].id)

    items = []
    for p in passages:
        excerpt = p.content[:_EXCERPT_LENGTH] if p.content else ""
        if len(p.content) > _EXCERPT_LENGTH:
            excerpt += "..."
        items.append(
            PassageListItem(
                id=p.id,
                title=p.title,
                language=p.language,
                cefr_level=p.cefr_level,
                topic=p.topic,
                word_count=p.word_count,
                estimated_minutes=p.estimated_minutes,
                is_generated=p.is_generated,
                style=p.style,
                length=p.length,
                reading_progress=p.reading_progress,
                excerpt=excerpt,
                created_at=p.created_at,
                updated_at=p.updated_at,
            )
        )

    return items, next_cursor


# ---------------------------------------------------------------------------
# Get
# ---------------------------------------------------------------------------


async def get_passage(
    db: AsyncSession,
    user_id: uuid.UUID,
    passage_id: uuid.UUID,
) -> Passage | None:
    """Fetch a single passage with vocabulary annotations.

    Returns ``None`` if not found, not owned, or soft-deleted.
    """
    stmt = select(Passage).where(
        Passage.id == passage_id,
        Passage.user_id == user_id,
        Passage.deleted_at.is_(None),
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


async def update_passage(
    db: AsyncSession,
    user_id: uuid.UUID,
    passage_id: uuid.UUID,
    *,
    reading_progress: float | None = None,
    bookmark_position: int | None = None,
) -> Passage | None:
    """Update reading progress or bookmark position.

    Returns ``None`` if not found or not owned.
    """
    passage = await get_passage(db, user_id, passage_id)
    if passage is None:
        return None

    if reading_progress is not None:
        passage.reading_progress = reading_progress
    if bookmark_position is not None:
        passage.bookmark_position = bookmark_position

    await db.flush()
    await db.refresh(passage)
    return passage


# ---------------------------------------------------------------------------
# Delete (soft)
# ---------------------------------------------------------------------------


async def delete_passage(
    db: AsyncSession,
    user_id: uuid.UUID,
    passage_id: uuid.UUID,
) -> bool:
    """Soft-delete a passage.  Returns ``False`` if not found/not owned."""
    passage = await get_passage(db, user_id, passage_id)
    if passage is None:
        return False

    passage.deleted_at = datetime.utcnow()
    await db.flush()
    return True
