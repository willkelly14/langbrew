"""Home screen aggregation endpoint."""

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.schemas.home import HomeResponse
from app.services import home_service, user_service

logger = structlog.stdlib.get_logger()

router = APIRouter(prefix="/home", tags=["home"])


@router.get("", response_model=HomeResponse)
async def get_home(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> HomeResponse:
    """Aggregated home screen data.

    Returns everything the iOS home tab needs in a single call: user summary,
    active language, streak information, cards due, today's passage, current
    book, and vocabulary statistics.
    """
    user = await user_service.get_or_create_user(db, auth.sub, auth.email)
    return await home_service.get_home_data(db, user)
