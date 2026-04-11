"""Tests for the /v1/talk family of endpoints."""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient
    from sqlalchemy.ext.asyncio import AsyncSession


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FAKE_PARTNER_ID = "partner-luna"


async def _setup_user_with_language(
    client: AsyncClient,
    language: str = "es",
    cefr_level: str = "B1",
) -> str:
    """Create user + active language; return user_id."""
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
    return user_id


async def _seed_partner(
    db_session: AsyncSession, partner_id: str = FAKE_PARTNER_ID
) -> None:
    """Insert a ConversationPartner row directly into the DB."""
    from app.models.conversation_partner import ConversationPartner

    partner = ConversationPartner(
        id=partner_id,
        name="Luna",
        personality_tag="friendly,curious",
        system_prompt_template="You are Luna, a helpful language tutor.",
        avatar_url="https://example.com/luna.png",
        voice_config={},
    )
    db_session.add(partner)
    await db_session.commit()


async def _create_conversation_in_db(
    db_session: AsyncSession,
    user_id: str,
    partner_id: str = FAKE_PARTNER_ID,
    *,
    topic: str = "travel",
    language: str = "es",
    cefr_level: str = "B1",
    created_at: object = None,
) -> object:
    """Insert a Conversation directly into the DB, bypassing the API.

    Pass ``created_at`` to give the conversation a specific timestamp; useful
    when testing cursor-based pagination which relies on distinct timestamps.
    """
    from datetime import UTC, datetime

    from app.models.conversation import Conversation
    from app.models.enums import CEFRLevel, ConversationStatus

    now = datetime.now(tz=UTC)
    conv = Conversation(
        user_id=uuid.UUID(user_id),
        partner_id=partner_id,
        topic=topic,
        language=language,
        cefr_level=CEFRLevel(cefr_level),
        status=ConversationStatus.ACTIVE,
        started_at=created_at or now,
    )
    if created_at is not None:
        conv.created_at = created_at
        conv.updated_at = created_at
    db_session.add(conv)
    await db_session.commit()
    await db_session.refresh(conv)
    return conv


# ---------------------------------------------------------------------------
# Schema unit tests — no DB or HTTP needed
# ---------------------------------------------------------------------------


def test_create_conversation_request_valid() -> None:
    """CreateConversationRequest accepts valid input."""
    from app.schemas.talk import CreateConversationRequest

    req = CreateConversationRequest(partner_id="luna", topic="ordering coffee")
    assert req.partner_id == "luna"
    assert req.topic == "ordering coffee"
    assert req.language is None


def test_create_conversation_request_with_language() -> None:
    """CreateConversationRequest accepts an optional language override."""
    from app.schemas.talk import CreateConversationRequest

    req = CreateConversationRequest(partner_id="luna", topic="food", language="fr")
    assert req.language == "fr"


def test_create_conversation_request_topic_too_long() -> None:
    """CreateConversationRequest rejects topic longer than 255 characters."""
    from pydantic import ValidationError

    from app.schemas.talk import CreateConversationRequest

    with pytest.raises(ValidationError):
        CreateConversationRequest(partner_id="luna", topic="x" * 256)


def test_send_message_request_valid() -> None:
    """SendMessageRequest accepts valid text content."""
    from app.schemas.talk import SendMessageRequest

    req = SendMessageRequest(text_content="Hola, ¿cómo estás?")
    assert req.text_content == "Hola, ¿cómo estás?"


def test_send_message_request_too_long() -> None:
    """SendMessageRequest rejects text_content longer than 5000 characters."""
    from pydantic import ValidationError

    from app.schemas.talk import SendMessageRequest

    with pytest.raises(ValidationError):
        SendMessageRequest(text_content="a" * 5001)


def test_partner_response_from_attributes() -> None:
    """PartnerResponse.model_validate works with an ORM-like object."""
    from app.schemas.talk import PartnerResponse

    class FakePartner:
        id = "partner-luna"
        name = "Luna"
        personality_tag = "friendly"
        avatar_url = "https://example.com/luna.png"

    resp = PartnerResponse.model_validate(FakePartner())
    assert resp.id == "partner-luna"
    assert resp.name == "Luna"
    assert resp.personality_tag == "friendly"
    assert resp.avatar_url == "https://example.com/luna.png"


def test_conversation_response_from_attributes() -> None:
    """ConversationResponse.model_validate works with an ORM-like object."""
    from datetime import UTC, datetime

    from app.schemas.talk import ConversationResponse

    now = datetime.now(tz=UTC)
    conv_id = uuid.uuid4()

    class FakeConv:
        id = conv_id
        partner_id = "partner-luna"
        partner_name = ""
        topic = "travel"
        language = "es"
        cefr_level = "B1"
        status = "active"
        message_count = 0
        last_message_preview = None
        last_message_at = None
        has_unread = False
        started_at = now
        ended_at = None
        created_at = now

    resp = ConversationResponse.model_validate(FakeConv())
    assert resp.id == conv_id
    assert resp.topic == "travel"
    assert resp.language == "es"
    assert resp.status == "active"


# ---------------------------------------------------------------------------
# Service unit test — _build_chat_system_prompt
# ---------------------------------------------------------------------------


def test_build_chat_system_prompt_contains_expected_content() -> None:
    """_build_chat_system_prompt embeds partner name, personality, language and level."""
    from app.services.ai_service import _build_chat_system_prompt

    prompt = _build_chat_system_prompt(
        partner_name="Luna",
        partner_personality="friendly,curious",
        system_prompt_template="You are a helpful tutor.",
        language="es",
        cefr_level="B1",
    )

    assert "Luna" in prompt
    assert "friendly,curious" in prompt
    assert "es" in prompt
    assert "B1" in prompt
    assert "You are a helpful tutor." in prompt


def test_build_chat_system_prompt_guidelines_present() -> None:
    """_build_chat_system_prompt always includes the guidelines block."""
    from app.services.ai_service import _build_chat_system_prompt

    prompt = _build_chat_system_prompt(
        partner_name="Marco",
        partner_personality="serious",
        system_prompt_template="Template here.",
        language="it",
        cefr_level="A2",
    )

    assert "Be encouraging" in prompt
    assert "Stay in character" in prompt


# ---------------------------------------------------------------------------
# GET /v1/talk/partners
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_partners_empty_when_no_partners(client: AsyncClient) -> None:
    """GET /v1/talk/partners returns an empty list when no partners exist."""
    resp = await client.get("/v1/talk/partners")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.anyio
async def test_list_partners_returns_seeded_partner(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/partners returns a partner that was seeded in the DB."""
    await _seed_partner(db_session)

    resp = await client.get("/v1/talk/partners")
    assert resp.status_code == 200
    partners = resp.json()
    assert len(partners) == 1
    assert partners[0]["id"] == FAKE_PARTNER_ID
    assert partners[0]["name"] == "Luna"
    assert "personality_tag" in partners[0]
    assert "avatar_url" in partners[0]


@pytest.mark.anyio
async def test_list_partners_multiple_ordered_by_name(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/partners returns partners sorted alphabetically by name."""
    from app.models.conversation_partner import ConversationPartner

    for pid, name in [("p-zara", "Zara"), ("p-adam", "Adam"), ("p-mia", "Mia")]:
        db_session.add(
            ConversationPartner(
                id=pid,
                name=name,
                personality_tag="neutral",
                system_prompt_template="prompt",
                avatar_url="",
                voice_config={},
            )
        )
    await db_session.commit()

    resp = await client.get("/v1/talk/partners")
    assert resp.status_code == 200
    names = [p["name"] for p in resp.json()]
    assert names == sorted(names)


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_conversation_happy_path(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations creates a conversation and returns 201."""
    await _setup_user_with_language(client)
    await _seed_partner(db_session)

    resp = await client.post(
        "/v1/talk/conversations",
        json={"partner_id": FAKE_PARTNER_ID, "topic": "ordering coffee"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert "id" in body
    assert body["partner_id"] == FAKE_PARTNER_ID
    assert body["partner_name"] == "Luna"
    assert body["topic"] == "ordering coffee"
    assert body["language"] == "es"
    assert body["status"] == "active"
    assert body["message_count"] == 0


@pytest.mark.anyio
async def test_create_conversation_language_override(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations respects an explicit language override."""
    await _setup_user_with_language(client, language="es")
    await _seed_partner(db_session)

    resp = await client.post(
        "/v1/talk/conversations",
        json={"partner_id": FAKE_PARTNER_ID, "topic": "cuisine", "language": "fr"},
    )
    assert resp.status_code == 201
    assert resp.json()["language"] == "fr"


@pytest.mark.anyio
async def test_create_conversation_no_active_language(client: AsyncClient) -> None:
    """POST /v1/talk/conversations returns 400 when no active language is set."""
    # Create user but skip language setup
    await client.get("/v1/me")

    resp = await client.post(
        "/v1/talk/conversations",
        json={"partner_id": FAKE_PARTNER_ID, "topic": "anything"},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.anyio
async def test_create_conversation_missing_partner_id(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations returns 422 when partner_id is missing."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/talk/conversations",
        json={"topic": "ordering coffee"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_create_conversation_missing_topic(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations returns 422 when topic is missing."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/talk/conversations",
        json={"partner_id": FAKE_PARTNER_ID},
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_conversations_empty_for_new_user(client: AsyncClient) -> None:
    """GET /v1/talk/conversations returns an empty list for a new user."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/talk/conversations")
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["next_cursor"] is None


@pytest.mark.anyio
async def test_list_conversations_returns_created_conversation(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations returns conversations seeded in the DB."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    await _create_conversation_in_db(db_session, user_id, topic="food")

    resp = await client.get("/v1/talk/conversations")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["topic"] == "food"
    assert items[0]["partner_name"] == "Luna"
    assert "id" in items[0]
    assert "status" in items[0]


@pytest.mark.anyio
async def test_list_conversations_language_filter(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations?language= filters by language."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    await _create_conversation_in_db(db_session, user_id, language="es", topic="A")
    await _create_conversation_in_db(db_session, user_id, language="fr", topic="B")

    resp = await client.get("/v1/talk/conversations?language=fr")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["language"] == "fr"


@pytest.mark.anyio
async def test_list_conversations_cursor_pagination(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations cursor pagination returns correct pages."""
    from datetime import UTC, datetime, timedelta

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)

    # Use explicit distinct timestamps so the cursor tiebreak logic works
    # reliably in SQLite (server_default=now() has only second resolution).
    base = datetime(2025, 6, 1, 12, 0, 0, tzinfo=UTC)
    for i in range(5):
        await _create_conversation_in_db(
            db_session,
            user_id,
            topic=f"topic {i}",
            created_at=base + timedelta(minutes=i),
        )

    resp1 = await client.get("/v1/talk/conversations?limit=2")
    assert resp1.status_code == 200
    body1 = resp1.json()
    assert len(body1["items"]) == 2
    assert body1["next_cursor"] is not None

    resp2 = await client.get(f"/v1/talk/conversations?limit=2&cursor={body1['next_cursor']}")
    assert resp2.status_code == 200
    body2 = resp2.json()
    assert len(body2["items"]) == 2

    # All IDs across the two pages must be unique
    ids_p1 = {i["id"] for i in body1["items"]}
    ids_p2 = {i["id"] for i in body2["items"]}
    assert ids_p1.isdisjoint(ids_p2)


@pytest.mark.anyio
async def test_list_conversations_user_isolation(
    client: AsyncClient, db_session: AsyncSession, app
) -> None:
    """Conversations created by user A are not visible to user B."""
    from app.core.auth import AuthenticatedUser, get_current_user

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    await _create_conversation_in_db(db_session, user_id, topic="private")

    other_uid = "other-uid-9999"

    def _other_user() -> AuthenticatedUser:
        return AuthenticatedUser(sub=other_uid, email="other@example.com")

    app.dependency_overrides[get_current_user] = _other_user
    try:
        resp = await client.get("/v1/talk/conversations")
        assert resp.status_code == 200
        assert resp.json()["items"] == []
    finally:
        from tests.conftest import FAKE_EMAIL, FAKE_SUB

        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            sub=FAKE_SUB, email=FAKE_EMAIL
        )


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations/{id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_conversation_returns_detail(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations/{id} returns conversation with messages list."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id, topic="ordering food")
    conv_id = str(conv.id)

    resp = await client.get(f"/v1/talk/conversations/{conv_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert "conversation" in body
    assert "messages" in body
    assert body["conversation"]["id"] == conv_id
    assert body["conversation"]["topic"] == "ordering food"
    assert isinstance(body["messages"], list)


@pytest.mark.anyio
async def test_get_conversation_marks_has_unread_false(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations/{id} clears the has_unread flag."""
    from app.models.conversation import Conversation
    from sqlalchemy import select

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    # Manually set has_unread = True
    stmt = select(Conversation).where(Conversation.id == conv.id)
    result = await db_session.execute(stmt)
    row = result.scalar_one()
    row.has_unread = True
    await db_session.commit()

    resp = await client.get(f"/v1/talk/conversations/{conv.id}")
    assert resp.status_code == 200

    await db_session.refresh(row)
    assert row.has_unread is False


@pytest.mark.anyio
async def test_get_conversation_not_found(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET /v1/talk/conversations/{id} returns 404 for unknown id."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000001"
    resp = await client.get(f"/v1/talk/conversations/{fake_id}")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "CONVERSATION_NOT_FOUND"


@pytest.mark.anyio
async def test_get_conversation_user_isolation(
    client: AsyncClient, db_session: AsyncSession, app
) -> None:
    """A conversation owned by user A returns 404 for user B."""
    from app.core.auth import AuthenticatedUser, get_current_user

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)
    conv_id = str(conv.id)

    other_uid = "other-uid-abcd"

    def _other_user() -> AuthenticatedUser:
        return AuthenticatedUser(sub=other_uid, email="other@example.com")

    app.dependency_overrides[get_current_user] = _other_user
    try:
        resp = await client.get(f"/v1/talk/conversations/{conv_id}")
        assert resp.status_code == 404
    finally:
        from tests.conftest import FAKE_EMAIL, FAKE_SUB

        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            sub=FAKE_SUB, email=FAKE_EMAIL
        )


# ---------------------------------------------------------------------------
# DELETE /v1/talk/conversations/{id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_conversation_returns_204(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """DELETE /v1/talk/conversations/{id} returns 204."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    resp = await client.delete(f"/v1/talk/conversations/{conv.id}")
    assert resp.status_code == 204


@pytest.mark.anyio
async def test_delete_conversation_removes_from_list(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """After DELETE, the conversation no longer appears in the list."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)
    conv_id = str(conv.id)

    await client.delete(f"/v1/talk/conversations/{conv_id}")

    list_resp = await client.get("/v1/talk/conversations")
    ids = [i["id"] for i in list_resp.json()["items"]]
    assert conv_id not in ids


@pytest.mark.anyio
async def test_delete_conversation_not_found(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """DELETE /v1/talk/conversations/{id} returns 404 for an unknown id."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000002"
    resp = await client.delete(f"/v1/talk/conversations/{fake_id}")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "CONVERSATION_NOT_FOUND"


@pytest.mark.anyio
async def test_delete_conversation_user_isolation(
    client: AsyncClient, db_session: AsyncSession, app
) -> None:
    """User B cannot delete a conversation owned by user A."""
    from app.core.auth import AuthenticatedUser, get_current_user

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)
    conv_id = str(conv.id)

    other_uid = "other-uid-xyz"

    def _other_user() -> AuthenticatedUser:
        return AuthenticatedUser(sub=other_uid, email="other@example.com")

    app.dependency_overrides[get_current_user] = _other_user
    try:
        resp = await client.delete(f"/v1/talk/conversations/{conv_id}")
        assert resp.status_code == 404
    finally:
        from tests.conftest import FAKE_EMAIL, FAKE_SUB

        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            sub=FAKE_SUB, email=FAKE_EMAIL
        )


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations/{id}/end
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_end_conversation_happy_path(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations/{id}/end returns {"status": "ended"}."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    with patch(
        "app.services.talk_service.generate_and_store_feedback",
        new_callable=AsyncMock,
    ):
        resp = await client.post(f"/v1/talk/conversations/{conv.id}/end")

    assert resp.status_code == 200
    assert resp.json() == {"status": "ended"}


@pytest.mark.anyio
async def test_end_conversation_sets_status_ended(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """After ending a conversation, GET detail reports status as 'ended'."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    with patch(
        "app.services.talk_service.generate_and_store_feedback",
        new_callable=AsyncMock,
    ):
        await client.post(f"/v1/talk/conversations/{conv.id}/end")

    # Verify the status change via the public API (avoids cross-session cache)
    detail_resp = await client.get(f"/v1/talk/conversations/{conv.id}")
    assert detail_resp.status_code == 200
    assert detail_resp.json()["conversation"]["status"] == "ended"
    assert detail_resp.json()["conversation"]["ended_at"] is not None


@pytest.mark.anyio
async def test_end_conversation_not_found(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations/{id}/end returns 404 for unknown id."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000003"
    resp = await client.post(f"/v1/talk/conversations/{fake_id}/end")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "CONVERSATION_NOT_FOUND"


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations/{id}/feedback
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_feedback_returns_202_when_not_generated(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET feedback returns 202 when feedback is not yet available."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    resp = await client.get(f"/v1/talk/conversations/{conv.id}/feedback")
    assert resp.status_code == 202
    assert resp.json()["status"] == "generating"


@pytest.mark.anyio
async def test_get_feedback_returns_feedback_when_available(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET feedback returns the feedback object when it has been generated."""
    from datetime import UTC, datetime

    from app.models.conversation_feedback import ConversationFeedback

    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    feedback = ConversationFeedback(
        conversation_id=conv.id,
        overall_score=75,
        grammar_score=70,
        vocabulary_score=80,
        fluency_score=72,
        confidence_score=78,
        summary="Good effort!",
        strengths={"label": "Strength", "text": "Nice vocabulary use."},
        tips={"label": "Try this", "text": "Work on verb conjugation."},
        corrections=[],
    )
    db_session.add(feedback)
    await db_session.commit()

    resp = await client.get(f"/v1/talk/conversations/{conv.id}/feedback")
    assert resp.status_code == 200
    body = resp.json()
    assert body["overall_score"] == 75
    assert body["grammar_score"] == 70
    assert body["vocabulary_score"] == 80
    assert body["summary"] == "Good effort!"
    assert "id" in body
    assert "conversation_id" in body


@pytest.mark.anyio
async def test_get_feedback_not_found_conversation(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """GET feedback returns 404 when conversation does not exist."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000004"
    resp = await client.get(f"/v1/talk/conversations/{fake_id}/feedback")
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "CONVERSATION_NOT_FOUND"


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations/{id}/messages (SSE) — skipped in CI
# ---------------------------------------------------------------------------


@pytest.mark.skip(
    reason="SSE event loop issues in test env — run in a dedicated session"
)
@pytest.mark.anyio
async def test_send_message_streams_response(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    """POST /v1/talk/conversations/{id}/messages streams token events."""
    user_id = await _setup_user_with_language(client)
    await _seed_partner(db_session)
    conv = await _create_conversation_in_db(db_session, user_id)

    async def _fake_stream(**_kwargs):
        yield "Hola"
        yield ", ¿cómo estás?"

    with patch(
        "app.services.ai_service.stream_chat_response",
        side_effect=_fake_stream,
    ):
        resp = await client.post(
            f"/v1/talk/conversations/{conv.id}/messages",
            json={"text_content": "Hello"},
        )
    assert resp.status_code == 200
