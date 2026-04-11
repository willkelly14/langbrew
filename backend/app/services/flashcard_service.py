"""Business logic for flashcard reviews, study sessions, and SM-2 algorithm."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING

import structlog
from sqlalchemy import and_, case, func, or_, select

from app.models.enums import (
    CardTypeFilter,
    StudyMode,
    VocabularyStatus,
    VocabularyType,
)
from app.models.review_event import ReviewEvent
from app.models.session_review import SessionReview
from app.models.study_session import StudySession
from app.models.user_streak import UserStreak
from app.models.vocabulary import VocabularyEncounter, VocabularyItem

if TYPE_CHECKING:
    import uuid

    from redis.asyncio import Redis
    from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.stdlib.get_logger()

# Redis cache TTL for stats
_STATS_CACHE_TTL = 60 * 60  # 1 hour


# ---------------------------------------------------------------------------
# SM-2 Algorithm
# ---------------------------------------------------------------------------


def calculate_sm2(
    quality: int,
    ease_factor: float,
    interval: int,
    repetitions: int,
) -> tuple[float, int, int, VocabularyStatus]:
    """SM-2 spaced repetition algorithm.

    Parameters
    ----------
    quality:
        Review quality: 1 (wrong) or 3 (right).
    ease_factor:
        Current ease factor (minimum 1.3).
    interval:
        Current interval in days.
    repetitions:
        Number of consecutive correct repetitions.

    Returns
    -------
    tuple
        (new_ease_factor, new_interval, new_repetitions, new_status)
    """
    if quality == 1:
        # Wrong answer: reset repetitions, short interval
        new_repetitions = 0
        new_interval = 0
        new_ease_factor = max(1.3, ease_factor - 0.2)
        new_status = VocabularyStatus.LEARNING
    else:
        # Right answer (quality == 3)
        new_repetitions = repetitions + 1
        if new_repetitions == 1:
            new_interval = 1
        elif new_repetitions == 2:
            new_interval = 6
        else:
            new_interval = round(interval * ease_factor)
        new_ease_factor = max(1.3, ease_factor + 0.1)
        new_status = (
            VocabularyStatus.MASTERED
            if new_repetitions >= 5
            else VocabularyStatus.KNOWN
        )

    return new_ease_factor, new_interval, new_repetitions, new_status


# ---------------------------------------------------------------------------
# Due cards query
# ---------------------------------------------------------------------------


def _apply_card_type_filter(
    stmt: select,  # type: ignore[type-arg]
    card_type_filter: CardTypeFilter | None,
) -> select:  # type: ignore[type-arg]
    """Apply vocabulary type filter to a query."""
    if card_type_filter is None or card_type_filter == CardTypeFilter.ALL:
        return stmt

    type_map = {
        CardTypeFilter.WORDS: VocabularyType.WORD,
        CardTypeFilter.PHRASES: VocabularyType.PHRASE,
        CardTypeFilter.SENTENCES: VocabularyType.SENTENCE,
    }
    vocab_type = type_map.get(card_type_filter)
    if vocab_type:
        stmt = stmt.where(VocabularyItem.type == vocab_type)
    return stmt


async def get_due_cards(
    db: AsyncSession,
    user_id: uuid.UUID,
    language: str,
    mode: StudyMode,
    card_type_filter: CardTypeFilter | None = None,
    limit: int = 25,
    *,
    count_only: bool = False,
) -> list[VocabularyItem] | int:
    """Query vocabulary items due for review based on mode.

    Parameters
    ----------
    db:
        Async database session.
    user_id:
        The user's ID.
    language:
        Target language code.
    mode:
        Study mode determining which cards to select.
    card_type_filter:
        Optional filter by vocabulary type.
    limit:
        Maximum number of cards to return.
    count_only:
        If True, return only the count instead of items.

    Returns
    -------
    list[VocabularyItem] | int
        List of vocabulary items or count.
    """
    today = datetime.now(tz=UTC).date()

    base_stmt = select(VocabularyItem).where(
        VocabularyItem.user_id == user_id,
        VocabularyItem.language == language,
    )
    base_stmt = _apply_card_type_filter(base_stmt, card_type_filter)

    if mode == StudyMode.DAILY:
        # Cards due today or new (never reviewed)
        stmt = base_stmt.where(
            or_(
                VocabularyItem.next_review_date <= today,
                VocabularyItem.next_review_date.is_(None),
            )
        ).order_by(
            # Prioritize overdue cards, then new ones
            case(
                (VocabularyItem.next_review_date.is_(None), 1),
                else_=0,
            ),
            VocabularyItem.next_review_date.asc(),
        )
    elif mode == StudyMode.HARDEST:
        # Lowest ease factor, exclude mastered
        stmt = base_stmt.where(
            VocabularyItem.status != VocabularyStatus.MASTERED,
        ).order_by(VocabularyItem.ease_factor.asc())
    elif mode == StudyMode.NEW:
        # New cards only, ordered by creation date
        stmt = base_stmt.where(
            VocabularyItem.status == VocabularyStatus.NEW,
        ).order_by(VocabularyItem.created_at.asc())
    elif mode == StudyMode.AHEAD:
        # Cards due within the next 7 days
        ahead_date = today + timedelta(days=7)
        stmt = base_stmt.where(
            VocabularyItem.next_review_date.is_not(None),
            VocabularyItem.next_review_date > today,
            VocabularyItem.next_review_date <= ahead_date,
        ).order_by(VocabularyItem.next_review_date.asc())
    elif mode == StudyMode.RANDOM:
        # Random sample from all items
        stmt = base_stmt.order_by(func.random())
    else:
        stmt = base_stmt

    if count_only:
        count_stmt = select(func.count()).select_from(stmt.subquery())
        result = await db.execute(count_stmt)
        return result.scalar_one()

    stmt = stmt.limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_due_count(
    db: AsyncSession,
    user_id: uuid.UUID,
    language: str,
) -> int:
    """Count cards due for review today (daily mode count)."""
    today = datetime.now(tz=UTC).date()
    stmt = select(func.count()).where(
        VocabularyItem.user_id == user_id,
        VocabularyItem.language == language,
        or_(
            VocabularyItem.next_review_date <= today,
            VocabularyItem.next_review_date.is_(None),
        ),
    )
    result = await db.execute(stmt)
    return result.scalar_one()


# ---------------------------------------------------------------------------
# Review processing
# ---------------------------------------------------------------------------


async def _update_user_streak(
    db: AsyncSession,
    user_id: uuid.UUID,
    language: str,
) -> None:
    """Increment the cards_reviewed counter on today's streak record."""
    today = datetime.now(tz=UTC).date()

    stmt = select(UserStreak).where(
        UserStreak.user_id == user_id,
        UserStreak.date == today,
        UserStreak.language == language,
    )
    result = await db.execute(stmt)
    streak = result.scalar_one_or_none()

    if streak is None:
        streak = UserStreak(
            user_id=user_id,
            date=today,
            language=language,
        )
        db.add(streak)
        await db.flush()

    streak.cards_reviewed += 1
    await db.flush()


async def process_review(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
    quality: int,
    response_time_ms: int | None = None,
    session_id: uuid.UUID | None = None,
) -> tuple[VocabularyItem, ReviewEvent]:
    """Process a flashcard review using the SM-2 algorithm.

    Parameters
    ----------
    db:
        Async database session.
    user_id:
        The user's ID.
    item_id:
        Vocabulary item ID being reviewed.
    quality:
        Review quality: 1 (wrong) or 3 (right).
    response_time_ms:
        Optional response time in milliseconds.
    session_id:
        Optional study session ID to link the review to.

    Returns
    -------
    tuple
        (updated_vocabulary_item, review_event)

    Raises
    ------
    ValueError
        If the vocabulary item is not found or not owned by the user.
    """
    # 1. Load vocabulary item and verify ownership
    stmt = select(VocabularyItem).where(
        VocabularyItem.id == item_id,
        VocabularyItem.user_id == user_id,
    )
    result = await db.execute(stmt)
    item = result.scalar_one_or_none()

    if item is None:
        raise ValueError("Vocabulary item not found")

    # 2. Calculate SM-2
    previous_ease_factor = item.ease_factor
    previous_interval = item.interval

    new_ease_factor, new_interval, new_repetitions, new_status = calculate_sm2(
        quality=quality,
        ease_factor=item.ease_factor,
        interval=item.interval,
        repetitions=item.repetitions,
    )

    # 3. Update vocabulary item
    item.ease_factor = new_ease_factor
    item.interval = new_interval
    item.repetitions = new_repetitions
    item.status = new_status
    item.times_reviewed += 1
    if quality == 3:
        item.times_correct += 1
    item.last_reviewed_at = datetime.now(tz=UTC)

    # Set next review date
    if new_interval > 0:
        item.next_review_date = datetime.now(tz=UTC).date() + timedelta(
            days=new_interval
        )
    else:
        # Review again soon (interval=0 means same day)
        item.next_review_date = datetime.now(tz=UTC).date()

    await db.flush()

    # 4. Create review event
    review_event = ReviewEvent(
        user_id=user_id,
        vocabulary_item_id=item_id,
        session_id=session_id,
        quality=quality,
        previous_ease_factor=previous_ease_factor,
        new_ease_factor=new_ease_factor,
        previous_interval=previous_interval,
        new_interval=new_interval,
        response_time_ms=response_time_ms,
    )
    db.add(review_event)
    await db.flush()

    # 5. If session_id: create session_review with next card_order
    if session_id:
        # Get current max card_order for this session
        order_stmt = select(func.coalesce(func.max(SessionReview.card_order), 0)).where(
            SessionReview.session_id == session_id,
        )
        order_result = await db.execute(order_stmt)
        next_order = order_result.scalar_one() + 1

        session_review = SessionReview(
            session_id=session_id,
            review_event_id=review_event.id,
            vocabulary_item_id=item_id,
            card_order=next_order,
        )
        db.add(session_review)

        # Update session counters
        session_stmt = select(StudySession).where(StudySession.id == session_id)
        session_result = await db.execute(session_stmt)
        session = session_result.scalar_one_or_none()
        if session:
            session.total_cards += 1
            if quality == 3:
                session.correct_count += 1
            else:
                session.incorrect_count += 1

        await db.flush()

    # 6. Update user streak
    await _update_user_streak(db, user_id, item.language)

    logger.info(
        "flashcard_reviewed",
        item_id=str(item_id),
        user_id=str(user_id),
        quality=quality,
        new_interval=new_interval,
        new_status=new_status,
    )

    return item, review_event


# ---------------------------------------------------------------------------
# Study sessions
# ---------------------------------------------------------------------------


async def create_study_session(
    db: AsyncSession,
    user_id: uuid.UUID,
    language: str,
    mode: StudyMode,
    card_limit: int = 25,
    card_type_filter: CardTypeFilter | None = None,
) -> StudySession:
    """Create a new study session."""
    session = StudySession(
        user_id=user_id,
        language=language,
        mode=mode,
        card_limit=card_limit,
        card_type_filter=card_type_filter,
    )
    db.add(session)
    await db.flush()
    await db.refresh(session)

    logger.info(
        "study_session_created",
        session_id=str(session.id),
        user_id=str(user_id),
        mode=mode,
    )
    return session


async def get_study_session(
    db: AsyncSession,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
) -> StudySession | None:
    """Fetch a single study session with its reviews."""
    stmt = select(StudySession).where(
        StudySession.id == session_id,
        StudySession.user_id == user_id,
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def list_study_sessions(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    cursor: str | None = None,
    limit: int = 20,
) -> tuple[list[StudySession], str | None]:
    """List study sessions with cursor-based pagination.

    Returns ``(items, next_cursor)``.
    """
    stmt = (
        select(StudySession)
        .where(StudySession.user_id == user_id)
        .order_by(StudySession.created_at.desc(), StudySession.id.desc())
    )

    if cursor:
        try:
            cursor_uuid = __import__("uuid").UUID(cursor)
            cursor_stmt = select(StudySession).where(StudySession.id == cursor_uuid)
            cursor_result = await db.execute(cursor_stmt)
            cursor_session = cursor_result.scalar_one_or_none()
            if cursor_session:
                stmt = stmt.where(
                    or_(
                        StudySession.created_at < cursor_session.created_at,
                        and_(
                            StudySession.created_at == cursor_session.created_at,
                            StudySession.id < cursor_uuid,
                        ),
                    )
                )
        except ValueError:
            pass

    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    sessions = list(result.scalars().all())

    next_cursor: str | None = None
    if len(sessions) > limit:
        sessions = sessions[:limit]
        next_cursor = str(sessions[-1].id)

    return sessions, next_cursor


async def complete_study_session(
    db: AsyncSession,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
    duration_seconds: int,
) -> StudySession | None:
    """Mark a study session as completed."""
    session = await get_study_session(db, user_id, session_id)
    if session is None:
        return None

    session.completed_at = datetime.now(tz=UTC)
    session.duration_seconds = duration_seconds
    await db.flush()
    await db.refresh(session)

    logger.info(
        "study_session_completed",
        session_id=str(session_id),
        total_cards=session.total_cards,
        duration=duration_seconds,
    )
    return session


async def create_restudy_session(
    db: AsyncSession,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
) -> tuple[StudySession, list[VocabularyItem]] | None:
    """Create a new session from missed cards in a previous session.

    Returns None if the original session is not found or has no missed cards.
    """
    original = await get_study_session(db, user_id, session_id)
    if original is None:
        return None

    # Find review events from this session where quality was wrong (1)
    missed_stmt = (
        select(VocabularyItem)
        .join(
            SessionReview,
            SessionReview.vocabulary_item_id == VocabularyItem.id,
        )
        .join(
            ReviewEvent,
            ReviewEvent.id == SessionReview.review_event_id,
        )
        .where(
            SessionReview.session_id == session_id,
            ReviewEvent.quality == 1,
        )
        .distinct()
    )
    result = await db.execute(missed_stmt)
    missed_items = list(result.scalars().all())

    if not missed_items:
        return None

    new_session = StudySession(
        user_id=user_id,
        language=original.language,
        mode=original.mode,
        card_limit=len(missed_items),
        card_type_filter=original.card_type_filter,
    )
    db.add(new_session)
    await db.flush()
    await db.refresh(new_session)

    return new_session, missed_items


# ---------------------------------------------------------------------------
# Vocabulary listing (enhanced)
# ---------------------------------------------------------------------------


async def list_vocabulary(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    language: str | None = None,
    search: str | None = None,
    type_filter: VocabularyType | None = None,
    status_filter: VocabularyStatus | None = None,
    cursor: str | None = None,
    limit: int = 20,
) -> tuple[list[VocabularyItem], str | None]:
    """List vocabulary items with filtering and cursor-based pagination."""
    stmt = (
        select(VocabularyItem)
        .where(VocabularyItem.user_id == user_id)
        .order_by(VocabularyItem.created_at.desc(), VocabularyItem.id.desc())
    )

    if language:
        stmt = stmt.where(VocabularyItem.language == language)
    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            or_(
                VocabularyItem.text.ilike(pattern),
                VocabularyItem.translation.ilike(pattern),
            )
        )
    if type_filter:
        stmt = stmt.where(VocabularyItem.type == type_filter)
    if status_filter:
        stmt = stmt.where(VocabularyItem.status == status_filter)

    if cursor:
        try:
            cursor_uuid = __import__("uuid").UUID(cursor)
            cursor_stmt = select(VocabularyItem).where(VocabularyItem.id == cursor_uuid)
            cursor_result = await db.execute(cursor_stmt)
            cursor_item = cursor_result.scalar_one_or_none()
            if cursor_item:
                stmt = stmt.where(
                    or_(
                        VocabularyItem.created_at < cursor_item.created_at,
                        and_(
                            VocabularyItem.created_at == cursor_item.created_at,
                            VocabularyItem.id < cursor_uuid,
                        ),
                    )
                )
        except ValueError:
            pass

    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    items = list(result.scalars().all())

    next_cursor: str | None = None
    if len(items) > limit:
        items = items[:limit]
        next_cursor = str(items[-1].id)

    return items, next_cursor


async def get_vocabulary_stats(
    db: AsyncSession,
    user_id: uuid.UUID,
    language: str | None = None,
) -> dict[str, int]:
    """Get aggregate vocabulary statistics."""
    base_where = [VocabularyItem.user_id == user_id]
    if language:
        base_where.append(VocabularyItem.language == language)

    # Status counts
    status_stmt = (
        select(
            VocabularyItem.status,
            func.count().label("count"),
        )
        .where(*base_where)
        .group_by(VocabularyItem.status)
    )
    status_result = await db.execute(status_stmt)
    status_counts = {row.status: row.count for row in status_result.all()}

    # Type counts
    type_stmt = (
        select(
            VocabularyItem.type,
            func.count().label("count"),
        )
        .where(*base_where)
        .group_by(VocabularyItem.type)
    )
    type_result = await db.execute(type_stmt)
    type_counts = {row.type: row.count for row in type_result.all()}

    total = sum(status_counts.values())

    return {
        "total": total,
        "new": status_counts.get(VocabularyStatus.NEW, 0),
        "learning": status_counts.get(VocabularyStatus.LEARNING, 0),
        "known": status_counts.get(VocabularyStatus.KNOWN, 0),
        "mastered": status_counts.get(VocabularyStatus.MASTERED, 0),
        "words": type_counts.get(VocabularyType.WORD, 0),
        "phrases": type_counts.get(VocabularyType.PHRASE, 0),
        "sentences": type_counts.get(VocabularyType.SENTENCE, 0),
    }


async def get_vocabulary_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
) -> VocabularyItem | None:
    """Fetch a single vocabulary item with full detail."""
    stmt = select(VocabularyItem).where(
        VocabularyItem.id == item_id,
        VocabularyItem.user_id == user_id,
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def update_vocabulary_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
    *,
    status: VocabularyStatus | None = None,
    translation: str | None = None,
    phonetic: str | None = None,
    word_type: str | None = None,
    definitions: list[dict] | None = None,
    example_sentence: str | None = None,
    reset_sm2: bool = False,
) -> VocabularyItem | None:
    """Update a vocabulary item."""
    item = await get_vocabulary_item(db, user_id, item_id)
    if item is None:
        return None

    if status is not None:
        item.status = status
    if translation is not None:
        item.translation = translation
    if phonetic is not None:
        item.phonetic = phonetic
    if word_type is not None:
        item.word_type = word_type
    if definitions is not None:
        item.definitions = definitions
    if example_sentence is not None:
        item.example_sentence = example_sentence

    if reset_sm2:
        item.ease_factor = 2.5
        item.interval = 0
        item.repetitions = 0
        item.next_review_date = None
        item.status = VocabularyStatus.NEW
        item.times_reviewed = 0
        item.times_correct = 0
        item.last_reviewed_at = None

    await db.flush()
    await db.refresh(item)
    return item


async def batch_create_vocabulary(
    db: AsyncSession,
    user_id: uuid.UUID,
    user_language_id: uuid.UUID,
    items_data: list[dict],
) -> tuple[list[VocabularyItem], int]:
    """Batch create vocabulary items, skipping duplicates.

    Returns (created_items, skipped_count).
    """
    created: list[VocabularyItem] = []
    skipped = 0

    for data in items_data:
        # Check for duplicate
        stmt = select(VocabularyItem).where(
            VocabularyItem.user_id == user_id,
            VocabularyItem.language == data["language"],
            VocabularyItem.text == data["text"],
        )
        result = await db.execute(stmt)
        if result.scalar_one_or_none() is not None:
            skipped += 1
            continue

        item = VocabularyItem(
            user_id=user_id,
            user_language_id=user_language_id,
            language=data["language"],
            type=data.get("type", VocabularyType.WORD),
            text=data["text"],
            translation=data["translation"],
            phonetic=data.get("phonetic"),
            word_type=data.get("word_type"),
            definitions=data.get("definitions"),
            example_sentence=data.get("example_sentence"),
        )
        db.add(item)
        created.append(item)

    if created:
        await db.flush()
        for item in created:
            await db.refresh(item)

    logger.info(
        "vocabulary_batch_created",
        user_id=str(user_id),
        created=len(created),
        skipped=skipped,
    )
    return created, skipped


async def get_encounter_history(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
) -> list[VocabularyEncounter]:
    """Get encounter history for a vocabulary item."""
    # Verify ownership
    item = await get_vocabulary_item(db, user_id, item_id)
    if item is None:
        return []

    stmt = (
        select(VocabularyEncounter)
        .where(VocabularyEncounter.vocabulary_item_id == item_id)
        .order_by(VocabularyEncounter.created_at.desc())
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


# ---------------------------------------------------------------------------
# Flashcard stats
# ---------------------------------------------------------------------------


async def get_flashcard_stats(
    db: AsyncSession,
    redis: Redis,  # type: ignore[type-arg]
    user_id: uuid.UUID,
    language: str,
) -> dict:
    """Compute comprehensive flashcard statistics.

    Results are cached in Redis for 1 hour.
    """
    cache_key = f"flashcard_stats:{user_id}:{language}"

    # Check cache
    cached = await redis.get(cache_key)
    if cached:
        logger.debug("flashcard_stats_cache_hit", user_id=str(user_id))
        return json.loads(cached)

    today = datetime.now(tz=UTC).date()

    # --- Mastery breakdown ---
    vocab_stats = await get_vocabulary_stats(db, user_id, language)
    mastery_breakdown = {
        "new": vocab_stats["new"],
        "learning": vocab_stats["learning"],
        "known": vocab_stats["known"],
        "mastered": vocab_stats["mastered"],
        "total": vocab_stats["total"],
    }

    # --- Streak data ---
    # Count consecutive days with review activity
    streak_stmt = (
        select(UserStreak.date)
        .where(
            UserStreak.user_id == user_id,
            UserStreak.language == language,
            UserStreak.cards_reviewed > 0,
        )
        .order_by(UserStreak.date.desc())
    )
    streak_result = await db.execute(streak_stmt)
    streak_dates = [row[0] for row in streak_result.all()]

    current_streak = 0
    check_date = today
    for d in streak_dates:
        if d == check_date:
            current_streak += 1
            check_date -= timedelta(days=1)
        elif d < check_date:
            break

    # Longest streak (simple scan)
    longest_streak = 0
    if streak_dates:
        run = 1
        sorted_dates = sorted(streak_dates)
        for i in range(1, len(sorted_dates)):
            if sorted_dates[i] == sorted_dates[i - 1] + timedelta(days=1):
                run += 1
            else:
                longest_streak = max(longest_streak, run)
                run = 1
        longest_streak = max(longest_streak, run)

    today_reviewed = today in streak_dates

    streak_data = {
        "current": current_streak,
        "longest": longest_streak,
        "today_reviewed": today_reviewed,
    }

    # --- Accuracy ---
    accuracy_stmt = select(
        func.count().label("total"),
        func.sum(case((ReviewEvent.quality == 3, 1), else_=0)).label("correct"),
    ).where(
        ReviewEvent.user_id == user_id,
    )
    # Join to filter by language
    accuracy_stmt = accuracy_stmt.join(
        VocabularyItem,
        VocabularyItem.id == ReviewEvent.vocabulary_item_id,
    ).where(VocabularyItem.language == language)

    accuracy_result = await db.execute(accuracy_stmt)
    accuracy_row = accuracy_result.one()
    total_reviews = accuracy_row.total or 0
    correct = accuracy_row.correct or 0
    incorrect = total_reviews - correct
    accuracy_pct = (correct / total_reviews * 100) if total_reviews > 0 else 0.0

    accuracy = {
        "total_reviews": total_reviews,
        "correct": correct,
        "incorrect": incorrect,
        "accuracy_percentage": round(accuracy_pct, 1),
    }

    # --- Forecast (next 30 days) ---
    forecast = []
    for i in range(30):
        forecast_date = today + timedelta(days=i)
        count_stmt = select(func.count()).where(
            VocabularyItem.user_id == user_id,
            VocabularyItem.language == language,
            VocabularyItem.next_review_date == forecast_date,
        )
        count_result = await db.execute(count_stmt)
        count = count_result.scalar_one()
        forecast.append(
            {
                "date": forecast_date.isoformat(),
                "count": count,
            }
        )

    # --- Velocity ---
    seven_days_ago = today - timedelta(days=7)
    thirty_days_ago = today - timedelta(days=30)

    seven_days_start = datetime.combine(seven_days_ago, datetime.min.time())
    new_7d_stmt = select(func.count()).where(
        VocabularyItem.user_id == user_id,
        VocabularyItem.language == language,
        VocabularyItem.created_at >= seven_days_start,
    )
    new_7d_result = await db.execute(new_7d_stmt)
    new_7d = new_7d_result.scalar_one()

    thirty_days_start = datetime.combine(thirty_days_ago, datetime.min.time())
    new_30d_stmt = select(func.count()).where(
        VocabularyItem.user_id == user_id,
        VocabularyItem.language == language,
        VocabularyItem.created_at >= thirty_days_start,
    )
    new_30d_result = await db.execute(new_30d_stmt)
    new_30d = new_30d_result.scalar_one()

    velocity = {
        "words_per_day_7d": round(new_7d / 7, 1),
        "words_per_day_30d": round(new_30d / 30, 1),
        "new_words_this_week": new_7d,
    }

    # --- Time spent ---
    time_stmt = select(
        func.count().label("sessions_count"),
        func.coalesce(func.sum(StudySession.duration_seconds), 0).label(
            "total_seconds"
        ),
    ).where(
        StudySession.user_id == user_id,
        StudySession.language == language,
        StudySession.completed_at.is_not(None),
    )
    time_result = await db.execute(time_stmt)
    time_row = time_result.one()
    sessions_count = time_row.sessions_count or 0
    total_seconds = time_row.total_seconds or 0
    avg_session = (total_seconds / sessions_count) if sessions_count > 0 else 0.0

    time_spent = {
        "total_seconds": total_seconds,
        "average_session_seconds": round(avg_session, 1),
        "sessions_count": sessions_count,
    }

    stats = {
        "mastery_breakdown": mastery_breakdown,
        "streak_data": streak_data,
        "accuracy": accuracy,
        "forecast": forecast,
        "velocity": velocity,
        "time_spent": time_spent,
    }

    # Cache the result
    await redis.setex(cache_key, _STATS_CACHE_TTL, json.dumps(stats))
    logger.info("flashcard_stats_cached", user_id=str(user_id), language=language)

    return stats
