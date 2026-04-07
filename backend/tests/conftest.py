"""Shared pytest fixtures for the LangBrew test suite."""

import os
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

# Set required env vars before any app imports
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test.db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-secret")
os.environ.setdefault("OPENROUTER_API_KEY", "test-key")
os.environ.setdefault("MISTRAL_API_KEY", "test-key")
os.environ.setdefault("R2_ACCESS_KEY_ID", "test-key")
os.environ.setdefault("R2_SECRET_ACCESS_KEY", "test-secret")
os.environ.setdefault("R2_ENDPOINT_URL", "https://test.r2.dev")
os.environ.setdefault("APP_ENV", "testing")


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture
def app() -> FastAPI:
    """Return the FastAPI application with dependency overrides."""
    from app.core.database import get_db
    from app.core.redis import get_redis
    from app.main import app as _app

    # Stub database session
    async def _mock_db() -> AsyncGenerator[AsyncMock, None]:
        mock_session = AsyncMock()
        mock_session.execute = AsyncMock(return_value=None)
        yield mock_session

    # Stub Redis client
    async def _mock_redis() -> AsyncMock:
        mock_redis = AsyncMock()
        mock_redis.ping = AsyncMock(return_value=True)
        return mock_redis

    _app.dependency_overrides[get_db] = _mock_db
    _app.dependency_overrides[get_redis] = _mock_redis

    yield _app  # type: ignore[misc]

    _app.dependency_overrides.clear()


@pytest.fixture
async def client(app: FastAPI) -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client wired to the test application."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
