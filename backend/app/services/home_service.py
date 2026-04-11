"""Business logic for the home screen aggregation endpoint."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo

import structlog
from sqlalchemy import and_, func, or_, select

from app.models.user_streak import UserStreak
from app.models.vocabulary import VocabularyItem
from app.schemas.home import HomeResponse, HomeUser, WordStats
from app.schemas.user_language import UserLanguageResponse

if TYPE_CHECKING:
    import uuid

    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()


def _current_week_dates(timezone: str) -> list[date]:
    """Return Mon-Sun dates for the current week in the user's timezone."""
    try:
        tz = ZoneInfo(timezone)
    except (KeyError, ValueError):
        tz = ZoneInfo("UTC")

    today = datetime.now(tz=tz).date()
    # Monday is weekday 0
    monday = today - timedelta(days=today.weekday())
    return [monday + timedelta(days=i) for i in range(7)]


async def _build_streak_week(
    db: AsyncSession,
    user_id: uuid.UUID,
    timezone: str,
) -> list[bool]:
    """Build a 7-element list (Mon-Sun) indicating study activity each day."""
    week_dates = _current_week_dates(timezone)
    monday = week_dates[0]
    sunday = week_dates[6]

    stmt = select(UserStreak.date).where(
        and_(
            UserStreak.user_id == user_id,
            UserStreak.date >= monday,
            UserStreak.date <= sunday,
            (
                (UserStreak.minutes_studied > 0)
                | (UserStreak.passages_read > 0)
                | (UserStreak.cards_reviewed > 0)
                | (UserStreak.chats_completed > 0)
                | (UserStreak.words_learned > 0)
            ),
        )
    )
    result = await db.execute(stmt)

    active_dates: set[date] = set()
    for (d,) in result.all():
        active_dates.add(d)

    return [d in active_dates for d in week_dates]


async def get_home_data(db: AsyncSession, user: User) -> HomeResponse:
    """Assemble all data needed for the home screen.

    Parameters
    ----------
    db:
        Async database session.
    user:
        The fully-loaded User ORM instance (with relationships).

    Returns
    -------
    HomeResponse
        Aggregated home screen data.
    """
    streak_week = await _build_streak_week(db, user.id, user.timezone)

    home_user = HomeUser(
        first_name=user.first_name,
        avatar_url=user.avatar_url,
        current_streak=user.current_streak,
        streak_week=streak_week,
    )

    active_language = (
        UserLanguageResponse.model_validate(user.active_language)
        if user.active_language
        else None
    )

    # Real vocabulary stats and cards due
    cards_due = 0
    word_stats = WordStats(total=0, learning=0, mastered=0)

    if user.active_language:
        language = user.active_language.target_language
        today = datetime.now(tz=UTC).date()

        # Count cards due for review today
        due_stmt = select(func.count()).where(
            VocabularyItem.user_id == user.id,
            VocabularyItem.language == language,
            or_(
                VocabularyItem.next_review_date <= today,
                VocabularyItem.next_review_date.is_(None),
            ),
        )
        due_result = await db.execute(due_stmt)
        cards_due = due_result.scalar_one()

        # Vocabulary stats by status
        from app.models.enums import VocabularyStatus

        stats_stmt = (
            select(
                VocabularyItem.status,
                func.count().label("count"),
            )
            .where(
                VocabularyItem.user_id == user.id,
                VocabularyItem.language == language,
            )
            .group_by(VocabularyItem.status)
        )
        stats_result = await db.execute(stats_stmt)
        status_counts = {row.status: row.count for row in stats_result.all()}

        total = sum(status_counts.values())
        learning = status_counts.get(VocabularyStatus.LEARNING, 0)
        mastered = status_counts.get(VocabularyStatus.MASTERED, 0)
        word_stats = WordStats(total=total, learning=learning, mastered=mastered)

    logger.debug("home_data_assembled", user_id=str(user.id))

    return HomeResponse(
        user=home_user,
        active_language=active_language,
        cards_due=cards_due,
        todays_passage=None,
        current_book=None,
        recent_books=[],
        word_stats=word_stats,
    )
