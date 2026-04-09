"""Tests for the /v1/vocabulary family of endpoints (Milestone 3)."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, patch

import pytest

if TYPE_CHECKING:
    from httpx import AsyncClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _setup_user_with_language(
    client: AsyncClient,
    language: str = "es",
    cefr_level: str = "B1",
) -> str:
    """Create user + active language; return the language id."""
    await client.get("/v1/me")
    resp = await client.post(
        "/v1/me/languages",
        json={"target_language": language, "cefr_level": cefr_level, "interests": []},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


_VOCAB_BASE = {
    "text": "prueba",
    "translation": "test",
    "language": "es",
    "type": "word",
}


# ---------------------------------------------------------------------------
# POST /v1/vocabulary — create
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_vocabulary_word_item(client: AsyncClient) -> None:
    """POST /v1/vocabulary creates a word item and returns 201."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary",
        json={
            "text": "hablar",
            "translation": "to speak",
            "language": "es",
            "type": "word",
            "phonetic": "aˈβlaɾ",
            "word_type": "verb",
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["text"] == "hablar"
    assert body["translation"] == "to speak"
    assert body["language"] == "es"
    assert body["type"] == "word"
    assert body["phonetic"] == "aˈβlaɾ"
    assert body["word_type"] == "verb"
    assert "id" in body
    assert "user_id" in body
    assert "user_language_id" in body


@pytest.mark.anyio
async def test_create_vocabulary_phrase_item(client: AsyncClient) -> None:
    """POST /v1/vocabulary creates a phrase type item."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary",
        json={
            "text": "buenos días",
            "translation": "good morning",
            "language": "es",
            "type": "phrase",
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["type"] == "phrase"
    assert body["text"] == "buenos días"


@pytest.mark.anyio
async def test_create_vocabulary_sm2_defaults(client: AsyncClient) -> None:
    """New vocabulary item has correct SM-2 default values."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary",
        json={"text": "correr", "translation": "to run", "language": "es"},
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["ease_factor"] == 2.5
    assert body["interval"] == 0
    assert body["repetitions"] == 0
    assert body["times_reviewed"] == 0
    assert body["times_correct"] == 0
    assert body["status"] == "new"
    assert body["next_review_date"] is None
    assert body["last_reviewed_at"] is None
    assert body["encounters"] == []


@pytest.mark.anyio
async def test_create_vocabulary_with_definitions(client: AsyncClient) -> None:
    """POST /v1/vocabulary accepts definitions list."""
    await _setup_user_with_language(client)

    definitions = [
        {
            "definition": "hacer una cosa por primera vez",
            "example": "Voy a intentar.",
            "meaning": "to try",
        },
    ]

    resp = await client.post(
        "/v1/vocabulary",
        json={
            "text": "intentar",
            "translation": "to try",
            "language": "es",
            "definitions": definitions,
            "example_sentence": "Voy a intentar aprender español.",
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["definitions"] is not None
    assert len(body["definitions"]) == 1
    assert body["example_sentence"] == "Voy a intentar aprender español."


@pytest.mark.anyio
async def test_create_vocabulary_duplicate_returns_409(client: AsyncClient) -> None:
    """POST /v1/vocabulary returns 409 for duplicate text+language combination."""
    await _setup_user_with_language(client)

    payload = {"text": "agua", "translation": "water", "language": "es"}

    first = await client.post("/v1/vocabulary", json=payload)
    assert first.status_code == 201

    second = await client.post("/v1/vocabulary", json=payload)
    assert second.status_code == 409
    body = second.json()
    assert body["detail"]["error"]["code"] == "VOCABULARY_EXISTS"
    assert "agua" in body["detail"]["error"]["message"]


@pytest.mark.anyio
async def test_create_vocabulary_requires_active_language(client: AsyncClient) -> None:
    """POST /v1/vocabulary returns 400 when no active language is set."""
    # Create user but no language
    await client.get("/v1/me")

    resp = await client.post(
        "/v1/vocabulary",
        json={"text": "hello", "translation": "hola", "language": "es"},
    )

    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.anyio
async def test_create_vocabulary_missing_required_field(client: AsyncClient) -> None:
    """POST /v1/vocabulary returns 422 when required fields are missing."""
    await _setup_user_with_language(client)

    # Missing translation
    resp = await client.post(
        "/v1/vocabulary",
        json={"text": "gato", "language": "es"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_create_vocabulary_empty_text_returns_422(client: AsyncClient) -> None:
    """POST /v1/vocabulary returns 422 for empty text."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary",
        json={"text": "", "translation": "something", "language": "es"},
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# DELETE /v1/vocabulary/{id} — remove
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_delete_vocabulary_item(client: AsyncClient) -> None:
    """DELETE /v1/vocabulary/{id} removes the item and returns 204."""
    await _setup_user_with_language(client)

    create_resp = await client.post(
        "/v1/vocabulary",
        json={"text": "borrar", "translation": "to erase", "language": "es"},
    )
    item_id = create_resp.json()["id"]

    resp = await client.delete(f"/v1/vocabulary/{item_id}")
    assert resp.status_code == 204


@pytest.mark.anyio
async def test_delete_vocabulary_item_not_found(client: AsyncClient) -> None:
    """DELETE /v1/vocabulary/{id} returns 404 for unknown id."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000010"
    resp = await client.delete(f"/v1/vocabulary/{fake_id}")

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "VOCABULARY_NOT_FOUND"


@pytest.mark.anyio
async def test_delete_vocabulary_item_user_isolation(client: AsyncClient, app) -> None:
    """A vocabulary item belonging to user A cannot be deleted by user B."""
    from app.core.auth import AuthenticatedUser, get_current_user
    from tests.conftest import FAKE_EMAIL, FAKE_SUB

    # Create item as the original user
    await _setup_user_with_language(client)
    create_resp = await client.post(
        "/v1/vocabulary",
        json={"text": "secreto", "translation": "secret", "language": "es"},
    )
    assert create_resp.status_code == 201
    item_id = create_resp.json()["id"]

    # Switch to other user
    other_uid = "other-uid-vocab-isolation"
    other_email = "other-vocab@example.com"

    def _other_user():
        return AuthenticatedUser(sub=other_uid, email=other_email)

    app.dependency_overrides[get_current_user] = _other_user
    try:
        resp = await client.delete(f"/v1/vocabulary/{item_id}")
        assert resp.status_code == 404
    finally:

        def _restore():
            return AuthenticatedUser(sub=FAKE_SUB, email=FAKE_EMAIL)

        app.dependency_overrides[get_current_user] = _restore


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/define — word definition with AI + Redis cache
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_define_word_returns_definition(client: AsyncClient) -> None:
    """POST /v1/vocabulary/define returns a definition response from the AI."""
    await _setup_user_with_language(client)

    ai_response = {
        "word": "casa",
        "phonetic": "ˈka.sa",
        "word_type": "noun",
        "definitions": [
            {
                "definition": "edificio donde vive la gente",
                "example": "Mi casa es grande.",
                "meaning": "house",
            }
        ],
        "example_sentence": "Vivo en una casa pequeña.",
    }

    with (
        patch(
            "app.services.ai_service.define_word", new_callable=AsyncMock
        ) as mock_define,
        patch("app.core.redis.get_redis") as _,
    ):
        mock_define.return_value = ai_response

        # Override redis to return None (cache miss) so the AI is called
        from app.core.redis import get_redis

        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(return_value=None)
        mock_redis.setex = AsyncMock(return_value=True)
        mock_redis.pipeline = AsyncMock(return_value=AsyncMock())
        mock_redis.pipeline.return_value.__aenter__ = AsyncMock(
            return_value=mock_redis.pipeline.return_value
        )
        mock_redis.pipeline.return_value.__aexit__ = AsyncMock(return_value=False)

        app_instance = client._transport.app  # type: ignore[attr-defined]
        app_instance.dependency_overrides[get_redis] = lambda: mock_redis

        resp = await client.post(
            "/v1/vocabulary/define",
            json={"word": "casa", "language": "es"},
        )

        # Restore
        from app.core.redis import get_redis as _get_redis

        if _get_redis in app_instance.dependency_overrides:
            del app_instance.dependency_overrides[_get_redis]

    assert resp.status_code == 200
    body = resp.json()
    assert body["word"] == "casa"
    assert body["phonetic"] == "ˈka.sa"
    assert body["word_type"] == "noun"
    assert len(body["definitions"]) == 1
    assert body["definitions"][0]["meaning"] == "house"
    assert body["example_sentence"] == "Vivo en una casa pequeña."


@pytest.mark.anyio
async def test_define_word_cache_hit_skips_ai(client: AsyncClient, app) -> None:
    """POST /v1/vocabulary/define uses Redis cache and skips AI on cache hit."""
    from app.core.redis import get_redis

    await _setup_user_with_language(client)

    cached_result = {
        "word": "perro",
        "phonetic": "ˈpe.ro",
        "word_type": "noun",
        "definitions": [
            {
                "definition": "animal doméstico",
                "example": "Tengo un perro.",
                "meaning": "dog",
            }
        ],
        "example_sentence": "El perro ladra.",
    }

    from unittest.mock import MagicMock

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=json.dumps(cached_result).encode())
    mock_redis.setex = AsyncMock()
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    with patch(
        "app.services.ai_service.define_word", new_callable=AsyncMock
    ) as mock_ai:
        resp = await client.post(
            "/v1/vocabulary/define",
            json={"word": "perro", "language": "es"},
        )

        # AI should NOT have been called because cache returned a value
        mock_ai.assert_not_called()

    assert resp.status_code == 200
    body = resp.json()
    assert body["word"] == "perro"
    assert body["definitions"][0]["meaning"] == "dog"


@pytest.mark.anyio
async def test_define_word_cache_miss_calls_ai_and_caches(
    client: AsyncClient, app
) -> None:
    """POST /v1/vocabulary/define calls AI on cache miss and stores result."""
    from app.core.redis import get_redis

    await _setup_user_with_language(client)

    ai_result = {
        "word": "flor",
        "phonetic": "floɾ",
        "word_type": "noun",
        "definitions": [
            {
                "definition": "planta con pétalos",
                "example": "Una flor bonita.",
                "meaning": "flower",
            }
        ],
        "example_sentence": "La flor es hermosa.",
    }

    from unittest.mock import MagicMock

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)  # cache miss
    mock_redis.setex = AsyncMock(return_value=True)
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    with patch(
        "app.services.ai_service.define_word", new_callable=AsyncMock
    ) as mock_ai:
        mock_ai.return_value = ai_result
        resp = await client.post(
            "/v1/vocabulary/define",
            json={"word": "flor", "language": "es"},
        )
        mock_ai.assert_called_once()

    assert resp.status_code == 200
    # setex was called to store in cache
    mock_redis.setex.assert_called_once()


@pytest.mark.anyio
async def test_define_word_missing_required_field(client: AsyncClient) -> None:
    """POST /v1/vocabulary/define returns 422 when word is missing."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary/define",
        json={"language": "es"},
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/translate — phrase translation with AI + Redis cache
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_translate_phrase_returns_translation(client: AsyncClient, app) -> None:
    """POST /v1/vocabulary/translate returns translation from AI."""
    from app.core.redis import get_redis

    await _setup_user_with_language(client)

    from unittest.mock import MagicMock

    ai_result = {"text": "Hola mundo", "translation": "Hello world"}

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.setex = AsyncMock(return_value=True)
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    with patch(
        "app.services.ai_service.translate_phrase", new_callable=AsyncMock
    ) as mock_ai:
        mock_ai.return_value = ai_result
        resp = await client.post(
            "/v1/vocabulary/translate",
            json={
                "text": "Hola mundo",
                "source_language": "es",
                "target_language": "en",
            },
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["text"] == "Hola mundo"
    assert body["translation"] == "Hello world"


@pytest.mark.anyio
async def test_translate_phrase_cache_hit_skips_ai(client: AsyncClient, app) -> None:
    """POST /v1/vocabulary/translate uses Redis cache on cache hit."""
    from app.core.redis import get_redis

    await _setup_user_with_language(client)

    from unittest.mock import MagicMock

    cached = {"text": "Buenos días", "translation": "Good morning"}

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=json.dumps(cached).encode())
    mock_redis.setex = AsyncMock()
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    with patch(
        "app.services.ai_service.translate_phrase", new_callable=AsyncMock
    ) as mock_ai:
        resp = await client.post(
            "/v1/vocabulary/translate",
            json={
                "text": "Buenos días",
                "source_language": "es",
                "target_language": "en",
            },
        )
        mock_ai.assert_not_called()

    assert resp.status_code == 200
    assert resp.json()["translation"] == "Good morning"


@pytest.mark.anyio
async def test_translate_phrase_increments_usage(client: AsyncClient, app) -> None:
    """POST /v1/vocabulary/translate increments translations_used counter."""
    from app.core.redis import get_redis

    await _setup_user_with_language(client)

    from unittest.mock import MagicMock

    ai_result = {"text": "gracias", "translation": "thank you"}

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.setex = AsyncMock(return_value=True)
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    # Get initial usage count
    usage_before = (await client.get("/v1/me/usage")).json()["translations_used"]

    with patch(
        "app.services.ai_service.translate_phrase", new_callable=AsyncMock
    ) as mock_ai:
        mock_ai.return_value = ai_result
        await client.post(
            "/v1/vocabulary/translate",
            json={"text": "gracias", "source_language": "es", "target_language": "en"},
        )

    usage_after = (await client.get("/v1/me/usage")).json()["translations_used"]
    assert usage_after == usage_before + 1


@pytest.mark.anyio
async def test_translate_phrase_usage_limit_exceeded(client: AsyncClient, app) -> None:
    """POST /v1/vocabulary/translate returns 402 at the free-tier limit."""
    from app.core.redis import get_redis
    from app.middleware.usage_meter import FREE_LIMITS

    await _setup_user_with_language(client)

    from unittest.mock import MagicMock

    limit = FREE_LIMITS["translations_used"]

    mock_redis = AsyncMock()
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.setex = AsyncMock(return_value=True)
    # Pipeline mock for rate limiter (sync chain, async execute)
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zadd = MagicMock(return_value=pipeline_mock)
    pipeline_mock.zcard = MagicMock(return_value=pipeline_mock)
    pipeline_mock.expire = MagicMock(return_value=pipeline_mock)
    pipeline_mock.execute = AsyncMock(return_value=[0, 1, 1, True])
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)

    app.dependency_overrides[get_redis] = lambda: mock_redis

    # Exhaust the translation limit
    for _ in range(limit):
        with patch(
            "app.services.ai_service.translate_phrase", new_callable=AsyncMock
        ) as mock_ai:
            mock_ai.return_value = {"text": "x", "translation": "y"}
            r = await client.post(
                "/v1/vocabulary/translate",
                json={"text": "x", "source_language": "es", "target_language": "en"},
            )
        assert r.status_code == 200

    # The next request should fail with 402
    resp = await client.post(
        "/v1/vocabulary/translate",
        json={"text": "más", "source_language": "es", "target_language": "en"},
    )
    assert resp.status_code == 402
    body = resp.json()
    assert body["detail"]["error"]["code"] == "USAGE_LIMIT_EXCEEDED"
    details = body["detail"]["error"]["details"]
    assert details["resource"] == "translations"
    assert details["limit"] == limit


@pytest.mark.anyio
async def test_translate_phrase_missing_required_fields(client: AsyncClient) -> None:
    """POST /v1/vocabulary/translate returns 422 when required fields are missing."""
    await _setup_user_with_language(client)

    # Missing target_language
    resp = await client.post(
        "/v1/vocabulary/translate",
        json={"text": "hola", "source_language": "es"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_translate_phrase_empty_text_returns_422(client: AsyncClient) -> None:
    """POST /v1/vocabulary/translate returns 422 for empty text."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary/translate",
        json={"text": "", "source_language": "es", "target_language": "en"},
    )
    assert resp.status_code == 422
