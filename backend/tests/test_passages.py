"""Tests for the /v1/passages family of endpoints (Milestone 3)."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.passage import Passage


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _setup_user_with_language(
    client: AsyncClient,
    language: str = "es",
    cefr_level: str = "B1",
) -> tuple[str, str]:
    """Create a user + active language via API; return (user_id, language_id)."""
    me_resp = await client.get("/v1/me")
    assert me_resp.status_code == 200
    user_id = me_resp.json()["user"]["id"]

    resp = await client.post(
        "/v1/me/languages",
        json={
            "target_language": language,
            "cefr_level": cefr_level,
            "interests": ["travel"],
        },
    )
    assert resp.status_code == 201
    return user_id, resp.json()["id"]


async def _create_passage_in_db(
    db_session: AsyncSession,
    user_id: str,
    user_language_id: str,
    *,
    title: str = "Test Passage",
    content: str = "Esta es una prueba.",
    language: str = "es",
    cefr_level: str = "B1",
    topic: str = "travel",
    style: str | None = None,
    length: str | None = None,
    word_count: int = 50,
    estimated_minutes: int = 3,
    created_at: datetime | None = None,
) -> Passage:
    """Insert a Passage directly into the database, bypassing the SSE endpoint.

    Pass ``created_at`` to give the passage a specific timestamp; useful when
    testing cursor-based pagination which relies on distinct timestamps.
    """
    from app.models.passage import Passage

    passage = Passage(
        user_id=uuid.UUID(user_id),
        user_language_id=uuid.UUID(user_language_id),
        title=title,
        content=content,
        language=language,
        cefr_level=cefr_level,
        topic=topic,
        word_count=word_count,
        estimated_minutes=estimated_minutes,
        is_generated=True,
        style=style,
        length=length,
    )
    if created_at is not None:
        passage.created_at = created_at
        passage.updated_at = created_at
    db_session.add(passage)
    await db_session.commit()
    await db_session.refresh(passage)
    return passage


# ---------------------------------------------------------------------------
# GET /v1/passages — list
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_passages_empty_for_new_user(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """New user with no passages returns an empty list."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/passages")
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["next_cursor"] is None


@pytest.mark.anyio
async def test_list_passages_returns_created_passages(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """List returns passages after they have been created directly in the DB."""
    user_id, lang_id = await _setup_user_with_language(client)
    await _create_passage_in_db(
        db_session, user_id, lang_id, title="My Passage", topic="food"
    )

    resp = await client.get("/v1/passages")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["title"] == "My Passage"
    assert items[0]["topic"] == "food"
    assert "id" in items[0]
    assert "excerpt" in items[0]
    assert "reading_progress" in items[0]


@pytest.mark.anyio
async def test_list_passages_search_filter(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """?search= filters passages by title and content."""
    user_id, lang_id = await _setup_user_with_language(client)

    await _create_passage_in_db(
        db_session, user_id, lang_id, title="Viaje a España", topic="travel"
    )
    await _create_passage_in_db(
        db_session, user_id, lang_id, title="Recetas Fáciles", topic="food"
    )

    resp = await client.get("/v1/passages?search=Viaje")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert "Viaje" in items[0]["title"]


@pytest.mark.anyio
async def test_list_passages_cefr_level_filter(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """?cefr_level= filters passages by CEFR level."""
    user_id, lang_id = await _setup_user_with_language(client, cefr_level="A1")

    await _create_passage_in_db(
        db_session,
        user_id,
        lang_id,
        title="B1 passage",
        cefr_level="B1",
        topic="history",
    )
    await _create_passage_in_db(
        db_session,
        user_id,
        lang_id,
        title="A1 passage",
        cefr_level="A1",
        topic="animals",
    )

    resp = await client.get("/v1/passages?cefr_level=B1")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["cefr_level"] == "B1"


@pytest.mark.anyio
async def test_list_passages_topic_filter(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """?topic= filters passages by topic substring."""
    user_id, lang_id = await _setup_user_with_language(client)

    await _create_passage_in_db(
        db_session, user_id, lang_id, title="About cooking", topic="cooking"
    )
    await _create_passage_in_db(
        db_session, user_id, lang_id, title="About sports", topic="sports"
    )

    resp = await client.get("/v1/passages?topic=cook")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["topic"] == "cooking"


@pytest.mark.anyio
async def test_list_passages_sort_by_date_desc(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Default sort is date descending — most recent first."""
    user_id, lang_id = await _setup_user_with_language(client)

    for i in range(3):
        await _create_passage_in_db(
            db_session, user_id, lang_id, title=f"Passage {i}", topic="misc"
        )

    resp = await client.get("/v1/passages?sort_by=date&sort_order=desc")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 3
    dates = [item["created_at"] for item in items]
    assert dates == sorted(dates, reverse=True)


@pytest.mark.anyio
async def test_list_passages_cursor_pagination(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Cursor-based pagination returns correct pages."""
    user_id, lang_id = await _setup_user_with_language(client)

    base = datetime(2026, 1, 1)
    for i in range(5):
        await _create_passage_in_db(
            db_session,
            user_id,
            lang_id,
            title=f"Passage {i}",
            topic="page",
            created_at=base + timedelta(minutes=i),
        )

    # First page: limit=2
    resp1 = await client.get("/v1/passages?limit=2")
    assert resp1.status_code == 200
    body1 = resp1.json()
    assert len(body1["items"]) == 2
    assert body1["next_cursor"] is not None

    # Second page using cursor
    cursor = body1["next_cursor"]
    resp2 = await client.get(f"/v1/passages?limit=2&cursor={cursor}")
    assert resp2.status_code == 200
    body2 = resp2.json()
    assert len(body2["items"]) == 2
    assert body2["next_cursor"] is not None

    # Third page — last page, no more cursor
    cursor2 = body2["next_cursor"]
    resp3 = await client.get(f"/v1/passages?limit=2&cursor={cursor2}")
    assert resp3.status_code == 200
    body3 = resp3.json()
    assert len(body3["items"]) == 1
    assert body3["next_cursor"] is None

    # Ensure all IDs across pages are unique
    all_ids = (
        [i["id"] for i in body1["items"]]
        + [i["id"] for i in body2["items"]]
        + [i["id"] for i in body3["items"]]
    )
    assert len(all_ids) == len(set(all_ids)) == 5


@pytest.mark.anyio
async def test_list_passages_invalid_cursor_ignored(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """An invalid cursor value is silently ignored; list is returned from beginning."""
    user_id, lang_id = await _setup_user_with_language(client)
    await _create_passage_in_db(db_session, user_id, lang_id, title="A", topic="x")

    resp = await client.get("/v1/passages?cursor=not-a-valid-uuid")
    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 1


@pytest.mark.anyio
async def test_list_passages_excludes_soft_deleted(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Soft-deleted passages are excluded from list results."""
    user_id, lang_id = await _setup_user_with_language(client)
    await _create_passage_in_db(
        db_session, user_id, lang_id, title="To Delete", topic="misc"
    )

    items = (await client.get("/v1/passages")).json()["items"]
    passage_id = items[0]["id"]

    del_resp = await client.delete(f"/v1/passages/{passage_id}")
    assert del_resp.status_code == 204

    resp = await client.get("/v1/passages")
    assert resp.status_code == 200
    assert resp.json()["items"] == []


# ---------------------------------------------------------------------------
# GET /v1/passages/{id} — detail
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_passage_returns_full_passage(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/passages/{id} returns passage with vocabulary_annotations."""
    from app.models.passage_vocabulary import PassageVocabulary

    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session,
        user_id,
        lang_id,
        title="My Story",
        content="Este es una prueba de contenido.",
        topic="stories",
    )

    # Add a vocabulary annotation directly in the DB
    vocab = PassageVocabulary(
        passage_id=passage.id,
        word="prueba",
        start_index=10,
        end_index=16,
        definition="test",
        translation="test",
        phonetic=None,
        word_type="noun",
        example_sentence="Es una prueba.",
    )
    db_session.add(vocab)
    await db_session.commit()

    resp = await client.get(f"/v1/passages/{passage.id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == str(passage.id)
    assert body["title"] == "My Story"
    assert body["content"] == "Este es una prueba de contenido."
    assert "vocabulary_annotations" in body
    assert isinstance(body["vocabulary_annotations"], list)
    assert len(body["vocabulary_annotations"]) == 1
    ann = body["vocabulary_annotations"][0]
    assert ann["word"] == "prueba"
    assert ann["translation"] == "test"


@pytest.mark.anyio
async def test_get_passage_not_found(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/passages/{id} returns 404 for a non-existent passage."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000001"
    resp = await client.get(f"/v1/passages/{fake_id}")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "PASSAGE_NOT_FOUND"


@pytest.mark.anyio
async def test_get_passage_user_isolation(
    client: AsyncClient, db_session: AsyncSession, app
) -> None:
    """A passage belonging to user A is not visible to user B."""
    from app.core.auth import AuthenticatedUser, get_current_user

    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Private", topic="private"
    )
    passage_id = str(passage.id)

    # Switch to a different user
    other_uid = "other-supabase-uid-5678"
    other_email = "other@example.com"

    def _other_user():
        return AuthenticatedUser(sub=other_uid, email=other_email)

    app.dependency_overrides[get_current_user] = _other_user
    try:
        resp = await client.get(f"/v1/passages/{passage_id}")
        assert resp.status_code == 404
    finally:
        from tests.conftest import FAKE_EMAIL, FAKE_SUB

        def _restore():
            return AuthenticatedUser(sub=FAKE_SUB, email=FAKE_EMAIL)

        app.dependency_overrides[get_current_user] = _restore


@pytest.mark.anyio
async def test_get_passage_soft_deleted_returns_404(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/passages/{id} returns 404 after a passage is soft-deleted."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Gone", topic="x"
    )
    passage_id = str(passage.id)

    await client.delete(f"/v1/passages/{passage_id}")

    resp = await client.get(f"/v1/passages/{passage_id}")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# PATCH /v1/passages/{id} — update
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_passage_reading_progress(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH updates reading_progress and returns the updated passage."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Update Me", topic="x"
    )

    resp = await client.patch(
        f"/v1/passages/{passage.id}", json={"reading_progress": 0.75}
    )
    assert resp.status_code == 200
    assert resp.json()["reading_progress"] == 0.75


@pytest.mark.anyio
async def test_update_passage_bookmark_position(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH updates bookmark_position and returns the updated passage."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Bookmark Me", topic="x"
    )

    resp = await client.patch(
        f"/v1/passages/{passage.id}", json={"bookmark_position": 42}
    )
    assert resp.status_code == 200
    assert resp.json()["bookmark_position"] == 42


@pytest.mark.anyio
async def test_update_passage_partial_update(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH with only one field leaves other fields unchanged."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Partial", topic="x"
    )
    passage_id = str(passage.id)

    # Set both fields first
    await client.patch(
        f"/v1/passages/{passage_id}",
        json={"reading_progress": 0.5, "bookmark_position": 100},
    )

    # Now update only reading_progress
    resp = await client.patch(
        f"/v1/passages/{passage_id}", json={"reading_progress": 0.9}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["reading_progress"] == 0.9
    # bookmark_position should be unchanged
    assert body["bookmark_position"] == 100


@pytest.mark.anyio
async def test_update_passage_not_found(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH on a non-existent passage returns 404."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000002"
    resp = await client.patch(f"/v1/passages/{fake_id}", json={"reading_progress": 0.5})
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "PASSAGE_NOT_FOUND"


@pytest.mark.anyio
async def test_update_passage_reading_progress_validation(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """PATCH rejects reading_progress outside the 0.0-1.0 range."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Validate", topic="x"
    )

    resp = await client.patch(
        f"/v1/passages/{passage.id}", json={"reading_progress": 1.5}
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# DELETE /v1/passages/{id} — soft delete
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_passage_soft_deletes(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """DELETE returns 204 and the passage no longer appears in list."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Delete Me", topic="x"
    )
    passage_id = str(passage.id)

    resp = await client.delete(f"/v1/passages/{passage_id}")
    assert resp.status_code == 204

    list_resp = await client.get("/v1/passages")
    ids = [i["id"] for i in list_resp.json()["items"]]
    assert passage_id not in ids


@pytest.mark.anyio
async def test_delete_passage_already_deleted_returns_404(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """Attempting to delete an already-deleted passage returns 404."""
    user_id, lang_id = await _setup_user_with_language(client)
    passage = await _create_passage_in_db(
        db_session, user_id, lang_id, title="Delete Twice", topic="x"
    )
    passage_id = str(passage.id)

    await client.delete(f"/v1/passages/{passage_id}")

    resp = await client.delete(f"/v1/passages/{passage_id}")
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_delete_nonexistent_passage_returns_404(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """DELETE on a passage that never existed returns 404."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000003"
    resp = await client.delete(f"/v1/passages/{fake_id}")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "PASSAGE_NOT_FOUND"


# ---------------------------------------------------------------------------
# POST /v1/passages/generate — SSE endpoint tests
# These tests exercise the SSE generate endpoint directly and are isolated
# at the end of the file because the sse_starlette anyio task group can
# corrupt the event loop reference held by AppStatus.should_exit_event when
# running under pytest-anyio.  They are skipped by default; run them in a
# dedicated pytest session if you need to verify SSE behaviour.
# ---------------------------------------------------------------------------


@pytest.mark.skip(
    reason="SSE event loop corruption in test env — run in dedicated session"
)
@pytest.mark.anyio
async def test_generate_passage_requires_active_language(client: AsyncClient) -> None:
    """generate returns 400 when no active language is set."""
    # Create user but no language
    await client.get("/v1/me")

    resp = await client.post(
        "/v1/passages/generate",
        json={"mode": "auto"},
    )
    assert resp.status_code == 400
    body = resp.json()
    assert body["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.skip(
    reason="SSE event loop corruption in test env — run in dedicated session"
)
@pytest.mark.anyio
async def test_generate_passage_usage_limit_exceeded(client: AsyncClient) -> None:
    """generate returns 402 when the user has hit the free-tier passage limit."""
    import json
    from unittest.mock import patch

    await _setup_user_with_language(client)

    from app.middleware.usage_meter import FREE_LIMITS

    limit = FREE_LIMITS["passages_generated"]

    vocab_entry = {"word": "w", "start_index": 0, "end_index": 1}
    passage_payload = json.dumps(
        {
            "title": "T",
            "content": "Hello world.",
            "topic": "x",
            "vocabulary": [vocab_entry],
        }
    )

    async def _fake_stream(**_kwargs):
        yield f"[FINAL]{passage_payload}"

    for _ in range(limit):
        with patch(
            "app.services.ai_service.generate_passage_stream", side_effect=_fake_stream
        ):
            resp = await client.post(
                "/v1/passages/generate",
                json={"mode": "auto"},
            )
        assert resp.status_code == 200

    # The (limit+1)th request should be rejected with 402
    resp = await client.post(
        "/v1/passages/generate",
        json={"mode": "auto"},
    )
    assert resp.status_code == 402
    body = resp.json()
    assert body["detail"]["error"]["code"] == "USAGE_LIMIT_EXCEEDED"
    details = body["detail"]["error"]["details"]
    assert details["resource"] == "passages"
    assert details["limit"] == limit
    assert details["used"] == limit
