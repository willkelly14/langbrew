"""Tests for the GET /v1/home endpoint (Milestone 2.4)."""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import TYPE_CHECKING

import pytest

from app.models.user_streak import UserStreak

if TYPE_CHECKING:
    from httpx import AsyncClient
    from sqlalchemy.ext.asyncio import AsyncSession


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _ensure_user(client: AsyncClient) -> dict:
    """Hit GET /v1/me to auto-create the test user; return the user dict."""
    resp = await client.get("/v1/me")
    assert resp.status_code == 200
    return resp.json()["user"]


# ---------------------------------------------------------------------------
# test_home_new_user
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_home_new_user(client: AsyncClient) -> None:
    """A fresh user gets the correct home response shape with zero/null values."""
    response = await client.get("/v1/home")

    assert response.status_code == 200
    body = response.json()

    # Top-level keys
    assert "user" in body
    assert "active_language" in body
    assert "cards_due" in body
    assert "todays_passage" in body
    assert "current_book" in body
    assert "recent_books" in body
    assert "word_stats" in body

    # user sub-object
    user = body["user"]
    assert "first_name" in user
    assert "avatar_url" in user
    assert user["current_streak"] == 0
    assert "streak_week" in user
    assert isinstance(user["streak_week"], list)
    assert len(user["streak_week"]) == 7
    assert all(isinstance(v, bool) for v in user["streak_week"])

    # New user has no language set
    assert body["active_language"] is None

    # Placeholder counters are all zero/empty
    assert body["cards_due"] == 0
    assert body["todays_passage"] is None
    assert body["current_book"] is None
    assert body["recent_books"] == []

    # word_stats
    word_stats = body["word_stats"]
    assert word_stats["total"] == 0
    assert word_stats["learning"] == 0
    assert word_stats["mastered"] == 0


@pytest.mark.anyio
async def test_home_new_user_streak_week_all_false(client: AsyncClient) -> None:
    """A fresh user with no activity has all-False streak_week."""
    response = await client.get("/v1/home")

    assert response.status_code == 200
    streak_week = response.json()["user"]["streak_week"]
    assert streak_week == [False] * 7


@pytest.mark.anyio
async def test_home_new_user_name_is_string(client: AsyncClient) -> None:
    """The user.first_name field is always a string, even when empty."""
    response = await client.get("/v1/home")

    assert response.status_code == 200
    user = response.json()["user"]
    assert isinstance(user["first_name"], str)


# ---------------------------------------------------------------------------
# test_home_with_language
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_home_with_language(client: AsyncClient) -> None:
    """After adding a language, active_language is populated in home response."""
    # Add a language
    lang_resp = await client.post(
        "/v1/me/languages",
        json={"target_language": "es", "cefr_level": "B1", "interests": ["travel"]},
    )
    assert lang_resp.status_code == 201

    response = await client.get("/v1/home")

    assert response.status_code == 200
    body = response.json()

    assert body["active_language"] is not None
    active = body["active_language"]
    assert active["target_language"] == "es"
    assert active["cefr_level"] == "B1"
    assert active["is_active"] is True
    assert "id" in active


@pytest.mark.anyio
async def test_home_active_language_switches_on_new_add(client: AsyncClient) -> None:
    """Adding a second language makes it the new active_language in home."""
    await client.post(
        "/v1/me/languages",
        json={"target_language": "fr", "cefr_level": "A2", "interests": []},
    )
    await client.post(
        "/v1/me/languages",
        json={"target_language": "de", "cefr_level": "B2", "interests": []},
    )

    response = await client.get("/v1/home")

    assert response.status_code == 200
    active = response.json()["active_language"]
    # The last language added should be active
    assert active["target_language"] == "de"


# ---------------------------------------------------------------------------
# test_home_streak_week
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_home_streak_week(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Streak rows for specific week dates produce the correct bool array."""
    # Create the user via the API so we get its UUID
    me_body = await _ensure_user(client)
    user_id = uuid.UUID(me_body["id"])

    # Determine the Monday of the current week
    today = date.today()
    monday = today - timedelta(days=today.weekday())

    # Insert streak rows for Monday (index 0) and Wednesday (index 2)
    streak_monday = UserStreak(
        user_id=user_id,
        date=monday,
        language="es",
        passages_read=1,
    )
    streak_wednesday = UserStreak(
        user_id=user_id,
        date=monday + timedelta(days=2),
        language="es",
        cards_reviewed=5,
    )
    db_session.add(streak_monday)
    db_session.add(streak_wednesday)
    await db_session.commit()

    response = await client.get("/v1/home")

    assert response.status_code == 200
    streak_week = response.json()["user"]["streak_week"]

    assert len(streak_week) == 7
    assert streak_week[0] is True  # Monday — has activity
    assert streak_week[1] is False  # Tuesday — no activity
    assert streak_week[2] is True  # Wednesday — has activity
    assert streak_week[3] is False  # Thursday
    assert streak_week[4] is False  # Friday
    assert streak_week[5] is False  # Saturday
    assert streak_week[6] is False  # Sunday


@pytest.mark.anyio
async def test_home_streak_week_activity_any_column(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Any non-zero activity column marks a day as True in streak_week."""
    me_body = await _ensure_user(client)
    user_id = uuid.UUID(me_body["id"])

    today = date.today()
    monday = today - timedelta(days=today.weekday())
    friday = monday + timedelta(days=4)

    # Each row tests a different activity column
    rows = [
        UserStreak(user_id=user_id, date=monday, language="es", minutes_studied=1),
        UserStreak(user_id=user_id, date=friday, language="es", chats_completed=1),
    ]
    for row in rows:
        db_session.add(row)
    await db_session.commit()

    response = await client.get("/v1/home")
    assert response.status_code == 200
    streak_week = response.json()["user"]["streak_week"]

    assert streak_week[0] is True  # Monday
    assert streak_week[4] is True  # Friday


@pytest.mark.anyio
async def test_home_streak_week_zero_activity_counts_as_false(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """A streak row where all activity columns are zero does not mark the day True."""
    me_body = await _ensure_user(client)
    user_id = uuid.UUID(me_body["id"])

    today = date.today()
    tuesday = today - timedelta(days=today.weekday()) + timedelta(days=1)

    # All activity columns default to 0 — row exists but should NOT light up
    zero_row = UserStreak(
        user_id=user_id,
        date=tuesday,
        language="es",
        # all activity fields left at default (0)
    )
    db_session.add(zero_row)
    await db_session.flush()

    response = await client.get("/v1/home")
    assert response.status_code == 200
    streak_week = response.json()["user"]["streak_week"]

    assert streak_week[1] is False  # Tuesday should still be False


@pytest.mark.anyio
async def test_home_streak_ignores_previous_week(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Activity from the previous week does not appear in this week's streak_week."""
    me_body = await _ensure_user(client)
    user_id = uuid.UUID(me_body["id"])

    today = date.today()
    monday = today - timedelta(days=today.weekday())
    last_monday = monday - timedelta(weeks=1)

    # Insert streak for last Monday only
    old_streak = UserStreak(
        user_id=user_id,
        date=last_monday,
        language="es",
        passages_read=3,
    )
    db_session.add(old_streak)
    await db_session.flush()

    response = await client.get("/v1/home")
    assert response.status_code == 200
    streak_week = response.json()["user"]["streak_week"]

    # Current week should be all False
    assert streak_week == [False] * 7
