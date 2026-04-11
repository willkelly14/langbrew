"""Background job for post-conversation feedback generation."""

from __future__ import annotations

import structlog

logger = structlog.stdlib.get_logger()

# NOTE: Feedback generation currently runs inline in the /end endpoint.
# This module will be expanded when ARQ is configured for background processing.
