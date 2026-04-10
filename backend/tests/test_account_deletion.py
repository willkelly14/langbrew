"""Tests for DELETE /v1/me/account (account deletion)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _create_user_with_name(client: AsyncClient, name: str) -> None:
    """Create a user and set their first name."""
    await client.get("/v1/me")  # auto-creates user
    await client.patch("/v1/me", json={"first_name": name})


# ---------------------------------------------------------------------------
# Success cases
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_account_success(client: AsyncClient) -> None:
    """DELETE /v1/me/account deletes the user and returns 200."""
    await _create_user_with_name(client, "Alice")

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        response = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "Alice-delete-account"},
        )

    assert response.status_code == 200
    body = response.json()
    assert "message" in body
    assert "permanently deleted" in body["message"].lower()


@pytest.mark.anyio
async def test_delete_account_case_insensitive(client: AsyncClient) -> None:
    """Confirmation string matching is case-insensitive."""
    await _create_user_with_name(client, "Alice")

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        response = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "alice-DELETE-ACCOUNT"},
        )

    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Validation errors
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_account_wrong_confirmation(client: AsyncClient) -> None:
    """DELETE /v1/me/account returns 400 when confirmation does not match."""
    await _create_user_with_name(client, "Alice")

    response = await client.request(
        "DELETE",
        "/v1/me/account",
        json={"confirmation": "wrong-text"},
    )

    assert response.status_code == 400
    body = response.json()
    assert body["detail"]["error"]["code"] == "INVALID_CONFIRMATION"


@pytest.mark.anyio
async def test_delete_account_empty_name_confirmation(client: AsyncClient) -> None:
    """User with empty first_name must type '-delete-account' to confirm."""
    # Auto-created user has empty first_name by default
    await client.get("/v1/me")

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        response = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "-delete-account"},
        )

    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Subscription guard
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_account_active_subscription_blocked(
    client: AsyncClient,
) -> None:
    """DELETE /v1/me/account returns 403 when user has active Fluency subscription."""
    await _create_user_with_name(client, "Bob")

    # Manually set subscription tier to FLUENCY with a future expiration.
    # We do this via a direct DB manipulation through the service layer.
    from sqlalchemy import update

    from app.core.database import get_db
    from app.main import app as _app
    from app.models.user import User

    # Get the overridden db dependency
    db_factory = _app.dependency_overrides[get_db]
    async for db in db_factory():
        stmt = (
            update(User)
            .where(User.first_name == "Bob")
            .values(
                subscription_tier="fluency",
                subscription_expires_at=datetime.now(tz=UTC) + timedelta(days=30),
            )
        )
        await db.execute(stmt)
        await db.commit()

    response = await client.request(
        "DELETE",
        "/v1/me/account",
        json={"confirmation": "Bob-delete-account"},
    )

    assert response.status_code == 403
    body = response.json()
    assert body["detail"]["error"]["code"] == "ACTIVE_SUBSCRIPTION"


@pytest.mark.anyio
async def test_delete_account_expired_subscription_allowed(
    client: AsyncClient,
) -> None:
    """DELETE /v1/me/account succeeds when Fluency subscription is expired."""
    await _create_user_with_name(client, "Carol")

    from sqlalchemy import update

    from app.core.database import get_db
    from app.main import app as _app
    from app.models.user import User

    db_factory = _app.dependency_overrides[get_db]
    async for db in db_factory():
        stmt = (
            update(User)
            .where(User.first_name == "Carol")
            .values(
                subscription_tier="fluency",
                subscription_expires_at=datetime.now(tz=UTC) - timedelta(days=1),
            )
        )
        await db.execute(stmt)
        await db.commit()

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        response = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "Carol-delete-account"},
        )

    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Cascade verification
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_account_cascades_languages(client: AsyncClient) -> None:
    """Deleting the account also removes the user's languages."""
    await _create_user_with_name(client, "Dana")

    # Add a language
    await client.post(
        "/v1/me/languages",
        json={"target_language": "es", "cefr_level": "B1", "interests": []},
    )

    # Verify language exists
    langs_resp = await client.get("/v1/me/languages")
    assert len(langs_resp.json()) == 1

    # Delete account
    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        response = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "Dana-delete-account"},
        )

    assert response.status_code == 200

    # The user is gone; a new GET /v1/me would auto-create a fresh user
    # with no languages.
    new_me = await client.get("/v1/me")
    assert new_me.status_code == 200
    new_langs = await client.get("/v1/me/languages")
    assert len(new_langs.json()) == 0


# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_account_second_call_creates_new_user(
    client: AsyncClient,
) -> None:
    """After deletion, GET /v1/me auto-creates a fresh user record."""
    await _create_user_with_name(client, "Eve")

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        first = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "Eve-delete-account"},
        )
    assert first.status_code == 200

    # A second DELETE should work on the new auto-created user
    # (which has an empty first_name).
    new_me = await client.get("/v1/me")
    assert new_me.status_code == 200
    assert new_me.json()["user"]["first_name"] == ""

    with patch(
        "app.services.account_service._delete_supabase_auth_user",
        new_callable=AsyncMock,
    ):
        second = await client.request(
            "DELETE",
            "/v1/me/account",
            json={"confirmation": "-delete-account"},
        )
    assert second.status_code == 200
