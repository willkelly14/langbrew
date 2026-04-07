"""Supabase JWT verification dependency."""

from typing import NamedTuple

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings

_bearer_scheme = HTTPBearer()


class AuthenticatedUser(NamedTuple):
    """Payload extracted from a verified Supabase JWT."""

    sub: str
    email: str


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> AuthenticatedUser:
    """Decode and verify a Supabase JWT.

    Returns an ``AuthenticatedUser`` containing the ``sub`` claim (Supabase
    user UUID) and the ``email`` claim.  Raises HTTP 401 if the token is
    missing, expired, or invalid.
    """
    token = credentials.credentials
    try:
        payload: dict[str, object] = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        ) from exc

    user_id = payload.get("sub")
    if not isinstance(user_id, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    email = payload.get("email", "")
    if not isinstance(email, str):
        email = ""

    return AuthenticatedUser(sub=user_id, email=email)
