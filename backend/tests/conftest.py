"""Shared pytest fixtures for the LangBrew test suite."""

from __future__ import annotations

import os
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

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
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Provide a fully functional in-memory SQLite session for each test.

    A fresh engine + schema is created per fixture invocation so every test
    starts with an empty database.
    """
    from app.models.base import Base

    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with factory() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
def app(db_session: AsyncSession) -> AsyncGenerator[FastAPI, None]:
    """Return the FastAPI application with dependency overrides."""
    from app.core.auth import AuthenticatedUser, get_current_user
    from app.core.database import get_db
    from app.core.redis import get_redis
    from app.main import app as _app

    async def _override_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    async def _mock_redis() -> AsyncMock:
        mock_redis = AsyncMock()
        mock_redis.ping = AsyncMock(return_value=True)
        return mock_redis

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
