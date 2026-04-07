"""Tests for the /v1/me family of endpoints (Milestone 1.2)."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient

# ---------------------------------------------------------------------------
# GET /v1/me
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_me_creates_user_on_first_call(client: AsyncClient) -> None:
    """First call to GET /v1/me auto-creates a user row and returns 200."""
    response = await client.get("/v1/me")

    assert response.status_code == 200
    body = response.json()
    assert "user" in body
    assert body["user"]["email"] == "testuser@example.com"
    assert body["user"]["supabase_uid"] == "test-supabase-uid-1234"


@pytest.mark.anyio
async def test_get_me_returns_existing_user(client: AsyncClient) -> None:
    """Subsequent calls to GET /v1/me return the same user without duplicating it."""
    response1 = await client.get("/v1/me")
    response2 = await client.get("/v1/me")

    assert response1.status_code == 200
    assert response2.status_code == 200
    assert response1.json()["user"]["id"] == response2.json()["user"]["id"]


@pytest.mark.anyio
async def test_get_me_includes_active_language(client: AsyncClient) -> None:
    """GET /v1/me reflects the active language after one has been created."""
    # No language yet — active_language should be null
    response = await client.get("/v1/me")
    assert response.status_code == 200
    assert response.json()["active_language"] is None

    # Add a language
    await client.post(
        "/v1/me/languages",
        json={"target_language": "es", "cefr_level": "B1", "interests": []},
    )

    response = await client.get("/v1/me")
    assert response.status_code == 200
    body = response.json()
    assert body["active_language"] is not None
    assert body["active_language"]["target_language"] == "es"


# ---------------------------------------------------------------------------
# PATCH /v1/me
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_user_name(client: AsyncClient) -> None:
    """PATCH /v1/me updates the user's display name."""
    response = await client.patch("/v1/me", json={"name": "Alice"})

    assert response.status_code == 200
    assert response.json()["name"] == "Alice"


@pytest.mark.anyio
async def test_update_user_daily_goal(client: AsyncClient) -> None:
    """PATCH /v1/me updates daily_goal_minutes within the allowed range."""
    response = await client.patch("/v1/me", json={"daily_goal_minutes": 30})

    assert response.status_code == 200
    assert response.json()["daily_goal_minutes"] == 30


@pytest.mark.anyio
async def test_update_user_daily_goal_validation(client: AsyncClient) -> None:
    """PATCH /v1/me rejects daily_goal_minutes outside the 1-120 range."""
    response = await client.patch("/v1/me", json={"daily_goal_minutes": 0})

    assert response.status_code == 422


@pytest.mark.anyio
async def test_update_user_onboarding(client: AsyncClient) -> None:
    """PATCH /v1/me can mark onboarding as completed."""
    response = await client.patch(
        "/v1/me",
        json={"onboarding_completed": True, "onboarding_step": 5},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["onboarding_completed"] is True
    assert body["onboarding_step"] == 5


# ---------------------------------------------------------------------------
# PATCH /v1/me/settings
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_settings(client: AsyncClient) -> None:
    """PATCH /v1/me/settings updates reading and notification settings."""
    response = await client.patch(
        "/v1/me/settings",
        json={
            "reading_theme": "dark",
            "font_size": 18,
            "notifications_enabled": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reading_theme"] == "dark"
    assert body["font_size"] == 18
    assert body["notifications_enabled"] is False


@pytest.mark.anyio
async def test_update_settings_validation(client: AsyncClient) -> None:
    """PATCH /v1/me/settings rejects font_size outside the 10-32 range."""
    response = await client.patch("/v1/me/settings", json={"font_size": 5})

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# POST /v1/me/languages
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_language(client: AsyncClient) -> None:
    """POST /v1/me/languages creates a language and returns 201."""
    response = await client.post(
        "/v1/me/languages",
        json={"target_language": "fr", "cefr_level": "A2", "interests": ["food"]},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["target_language"] == "fr"
    assert body["cefr_level"] == "A2"
    assert body["is_active"] is True
    assert body["interests"] == ["food"]
    assert "id" in body


@pytest.mark.anyio
async def test_create_language_missing_required_field(client: AsyncClient) -> None:
    """POST /v1/me/languages returns 422 when cefr_level is missing."""
    response = await client.post(
        "/v1/me/languages",
        json={"target_language": "de"},
    )

    assert response.status_code == 422


@pytest.mark.anyio
async def test_create_duplicate_language_returns_409(client: AsyncClient) -> None:
    """POST /v1/me/languages returns 409 when the same language is added twice."""
    payload = {"target_language": "ja", "cefr_level": "A1", "interests": []}

    first = await client.post("/v1/me/languages", json=payload)
    assert first.status_code == 201

    second = await client.post("/v1/me/languages", json=payload)
    assert second.status_code == 409


# ---------------------------------------------------------------------------
# GET /v1/me/languages
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_languages(client: AsyncClient) -> None:
    """GET /v1/me/languages returns all languages for the user."""
    # Empty to start
    response = await client.get("/v1/me/languages")
    assert response.status_code == 200
    assert response.json() == []

    # Add two languages
    await client.post(
        "/v1/me/languages",
        json={"target_language": "es", "cefr_level": "B1", "interests": []},
    )
    await client.post(
        "/v1/me/languages",
        json={"target_language": "de", "cefr_level": "A2", "interests": []},
    )

    response = await client.get("/v1/me/languages")
    assert response.status_code == 200
    languages = response.json()
    assert len(languages) == 2
    codes = {lang["target_language"] for lang in languages}
    assert codes == {"es", "de"}


# ---------------------------------------------------------------------------
# PATCH /v1/me/languages/{id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_language_cefr(client: AsyncClient) -> None:
    """PATCH /v1/me/languages/{id} updates the CEFR level."""
    create_resp = await client.post(
        "/v1/me/languages",
        json={"target_language": "pt", "cefr_level": "A1", "interests": []},
    )
    language_id = create_resp.json()["id"]

    response = await client.patch(
        f"/v1/me/languages/{language_id}",
        json={"cefr_level": "B2"},
    )

    assert response.status_code == 200
    assert response.json()["cefr_level"] == "B2"


@pytest.mark.anyio
async def test_update_nonexistent_language_returns_404(client: AsyncClient) -> None:
    """PATCH /v1/me/languages/{id} returns 404 for an unknown language id."""
    fake_id = "00000000-0000-0000-0000-000000000001"
    response = await client.patch(
        f"/v1/me/languages/{fake_id}",
        json={"cefr_level": "C1"},
    )

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# DELETE /v1/me/languages/{id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_language(client: AsyncClient) -> None:
    """DELETE /v1/me/languages/{id} removes the language and returns 204."""
    create_resp = await client.post(
        "/v1/me/languages",
        json={"target_language": "it", "cefr_level": "A1", "interests": []},
    )
    language_id = create_resp.json()["id"]

    response = await client.delete(f"/v1/me/languages/{language_id}")
    assert response.status_code == 204

    # Confirm it is gone
    list_resp = await client.get("/v1/me/languages")
    ids = [lang["id"] for lang in list_resp.json()]
    assert language_id not in ids


@pytest.mark.anyio
async def test_delete_nonexistent_language_returns_404(client: AsyncClient) -> None:
    """DELETE /v1/me/languages/{id} returns 404 for an unknown language id."""
    fake_id = "00000000-0000-0000-0000-000000000002"
    response = await client.delete(f"/v1/me/languages/{fake_id}")

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# POST /v1/me/devices
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_register_device(client: AsyncClient) -> None:
    """POST /v1/me/devices registers a push token and returns 201."""
    response = await client.post(
        "/v1/me/devices",
        json={"token": "abc123devicetoken", "platform": "ios"},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["token"] == "abc123devicetoken"
    assert body["platform"] == "ios"
    assert "id" in body


@pytest.mark.anyio
async def test_register_device_upserts_on_duplicate_token(
    client: AsyncClient,
) -> None:
    """POST /v1/me/devices with the same token updates rather than duplicating."""
    payload = {"token": "same-token-xyz", "platform": "ios"}

    first = await client.post("/v1/me/devices", json=payload)
    second = await client.post("/v1/me/devices", json=payload)

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]


# ---------------------------------------------------------------------------
# DELETE /v1/me/devices/{token}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_unregister_device(client: AsyncClient) -> None:
    """DELETE /v1/me/devices/{token} removes the token and returns 204."""
    token_value = "token-to-delete-999"
    await client.post(
        "/v1/me/devices",
        json={"token": token_value, "platform": "ios"},
    )

    response = await client.delete(f"/v1/me/devices/{token_value}")
    assert response.status_code == 204


@pytest.mark.anyio
async def test_unregister_nonexistent_device_returns_404(
    client: AsyncClient,
) -> None:
    """DELETE /v1/me/devices/{token} returns 404 for an unknown token."""
    response = await client.delete("/v1/me/devices/no-such-token")
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# GET /v1/me/usage
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_usage_creates_meter(client: AsyncClient) -> None:
    """GET /v1/me/usage creates a usage meter on first call and returns counters."""
    response = await client.get("/v1/me/usage")

    assert response.status_code == 200
    body = response.json()
    assert body["subscription_tier"] == "free"
    assert body["passages_generated"] == 0
    assert body["talk_seconds"] == 0
    assert body["books_uploaded"] == 0
    assert body["listening_seconds"] == 0
    assert body["translations_used"] == 0
    assert "period_start" in body
    assert "period_end" in body
    assert "limits" in body
    assert "passages_generated" in body["limits"]


@pytest.mark.anyio
async def test_get_usage_idempotent(client: AsyncClient) -> None:
    """Repeated GET /v1/me/usage calls return the same period dates."""
    resp1 = await client.get("/v1/me/usage")
    resp2 = await client.get("/v1/me/usage")

    assert resp1.status_code == 200
    assert resp2.status_code == 200
    assert resp1.json()["period_start"] == resp2.json()["period_start"]
