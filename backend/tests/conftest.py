"""Shared pytest fixtures for the LangBrew test suite."""

from __future__ import annotations

import contextlib
import os
import tempfile
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from fastapi import FastAPI

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

# Fake user credentials used by all tests
FAKE_SUB = "test-supabase-uid-1234"
FAKE_EMAIL = "testuser@example.com"


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture
async def db_session_factory() -> AsyncGenerator[
    async_sessionmaker[AsyncSession], None
]:
    """
    Provide a file-backed SQLite session factory for each test.

    A temporary SQLite file is created per test invocation so every test
    starts with an empty database.  NullPool is used so that each session
    opens its own connection — this prevents SSE cancel scopes from
    corrupting a pooled connection used by later requests in the same test.
    Data persists within a test because all sessions share the same file.
    """
    from app.models.base import Base

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
        db_path = tmp.name

    url = f"sqlite+aiosqlite:///{db_path}"

    engine = create_async_engine(
        url,
        echo=False,
        connect_args={"check_same_thread": False},
        poolclass=NullPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    yield factory

    await engine.dispose()

    with contextlib.suppress(OSError):
        os.unlink(db_path)


@pytest.fixture
async def db_session(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> AsyncGenerator[AsyncSession, None]:
    """
    Convenience fixture: yields a single open session from the factory.

    Use this only in tests that do not simulate multiple independent HTTP
    requests (e.g. direct service-layer tests).  For endpoint tests use the
    ``app`` + ``client`` fixtures which create a fresh session per request.
    """
    async with db_session_factory() as session:
        yield session


def _make_redis_mock() -> AsyncMock:
    """Return a fully-configured Redis mock suitable for all test scenarios."""
    mock_redis = AsyncMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.set = AsyncMock(return_value=True)
    mock_redis.setex = AsyncMock(return_value=True)

    mock_pipe = MagicMock()
    mock_pipe.zremrangebyscore = MagicMock(return_value=mock_pipe)
    mock_pipe.zadd = MagicMock(return_value=mock_pipe)
    mock_pipe.zcard = MagicMock(return_value=mock_pipe)
    mock_pipe.expire = MagicMock(return_value=mock_pipe)
    mock_pipe.execute = AsyncMock(return_value=[0, 1, 1, True])

    mock_redis.pipeline = MagicMock(return_value=mock_pipe)

    return mock_redis


@pytest.fixture
def app(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> AsyncGenerator[FastAPI, None]:
    """Return the FastAPI application with dependency overrides.

    The database override opens a **new session per request** (matching the
    behaviour of the real ``get_db`` dependency) so that SSE cancel scopes
    cannot corrupt other connections.  NullPool ensures each connection is
    independent.  All sessions share the same temp SQLite file, so data
    written by one request is visible to the next within the same test.
    """
    from app.core.auth import AuthenticatedUser, get_current_user
    from app.core.database import get_db
    from app.core.redis import get_redis
    from app.main import app as _app

    async def _override_db() -> AsyncGenerator[AsyncSession, None]:
        async with db_session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    async def _mock_redis() -> AsyncMock:
        return _make_redis_mock()

    def _fake_current_user() -> AuthenticatedUser:
        return AuthenticatedUser(sub=FAKE_SUB, email=FAKE_EMAIL)

    _app.dependency_overrides[get_db] = _override_db
    _app.dependency_overrides[get_redis] = _mock_redis
    _app.dependency_overrides[get_current_user] = _fake_current_user

    yield _app  # type: ignore[misc]

    _app.dependency_overrides.clear()


@pytest.fixture
async def client(app: FastAPI) -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client wired to the test application."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
