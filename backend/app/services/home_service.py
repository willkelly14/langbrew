"""Business logic for the home screen aggregation endpoint."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo

import structlog
from sqlalchemy import and_, select

from app.models.user_streak import UserStreak
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
        name=user.name,
        avatar_url=user.avatar_url,
        current_streak=user.current_streak,
        streak_week=streak_week,
    )

    active_language = (
        UserLanguageResponse.model_validate(user.active_language)
        if user.active_language
        else None
    )

    # Placeholder values for features not yet implemented
    word_stats = WordStats(total=0, learning=0, mastered=0)

    logger.debug("home_data_assembled", user_id=str(user.id))

    return HomeResponse(
        user=home_user,
        active_language=active_language,
        cards_due=0,
        todays_passage=None,
        current_book=None,
        recent_books=[],
        word_stats=word_stats,
    )
