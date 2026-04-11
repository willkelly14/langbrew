"""Unit tests for the SM-2 algorithm (calculate_sm2) and Milestone 4 flashcard
endpoints: due cards, reviews, study sessions, and vocabulary management."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from pydantic import ValidationError

from app.models.enums import VocabularyStatus
from app.schemas.flashcard import FlashcardReviewRequest
from app.services.flashcard_service import calculate_sm2

if TYPE_CHECKING:
    from httpx import AsyncClient


# ===========================================================================
# SM-2 algorithm unit tests
# ===========================================================================


class TestSM2Algorithm:
    """Pure unit tests for the calculate_sm2 function.

    No database or HTTP layer involved — tests call the function directly.
    """

    # Default "fresh card" state mirrors VocabularyItem column defaults.
    DEFAULT_EASE = 2.5
    DEFAULT_INTERVAL = 0
    DEFAULT_REPETITIONS = 0

    # -----------------------------------------------------------------------
    # Happy path — correct answers
    # -----------------------------------------------------------------------

    def test_sm2_correct_first_review(self) -> None:
        """First correct answer: interval becomes 1, repetitions becomes 1."""
        ease, interval, reps, status = calculate_sm2(
            quality=3,
            ease_factor=self.DEFAULT_EASE,
            interval=self.DEFAULT_INTERVAL,
            repetitions=self.DEFAULT_REPETITIONS,
        )

        assert reps == 1
        assert interval == 1
        # Ease should increase (never below 1.3)
        assert ease >= self.DEFAULT_EASE
        assert status != VocabularyStatus.NEW

    def test_sm2_correct_second_review(self) -> None:
        """Second consecutive correct answer: interval becomes 6."""
        # Simulate state after first correct review
        ease, interval, reps, status = calculate_sm2(
            quality=3,
            ease_factor=self.DEFAULT_EASE,
            interval=1,
            repetitions=1,
        )

        assert reps == 2
        assert interval == 6

    def test_sm2_correct_third_review(self) -> None:
        """Third consecutive correct answer: interval = round(prev_interval * ease)."""
        ease_before = 2.6
        interval_before = 6
        reps_before = 2

        new_ease, new_interval, new_reps, _ = calculate_sm2(
            quality=3,
            ease_factor=ease_before,
            interval=interval_before,
            repetitions=reps_before,
        )

        assert new_reps == 3
        assert new_interval == round(interval_before * ease_before)

    def test_sm2_ease_increases_on_correct(self) -> None:
        """Ease factor grows by 0.1 on each correct answer."""
        ease_before = 2.5
        new_ease, _, _, _ = calculate_sm2(
            quality=3,
            ease_factor=ease_before,
            interval=1,
            repetitions=1,
        )
        assert new_ease == pytest.approx(ease_before + 0.1)

    # -----------------------------------------------------------------------
    # Wrong answers
    # -----------------------------------------------------------------------

    def test_sm2_wrong_resets_repetitions(self) -> None:
        """Wrong answer resets repetitions to 0 and interval to 0."""
        _, interval, reps, _ = calculate_sm2(
            quality=1,
            ease_factor=self.DEFAULT_EASE,
            interval=10,
            repetitions=4,
        )

        assert reps == 0
        assert interval == 0

    def test_sm2_wrong_decreases_ease(self) -> None:
        """Wrong answer decreases ease factor by 0.2."""
        ease_before = 2.5
        new_ease, _, _, _ = calculate_sm2(
            quality=1,
            ease_factor=ease_before,
            interval=0,
            repetitions=0,
        )

        assert new_ease == pytest.approx(ease_before - 0.2)

    def test_sm2_wrong_sets_learning_status(self) -> None:
        """Wrong answer always sets status to LEARNING."""
        _, _, _, status = calculate_sm2(
            quality=1,
            ease_factor=2.5,
            interval=30,
            repetitions=10,
        )

        assert status == VocabularyStatus.LEARNING

    # -----------------------------------------------------------------------
    # Ease floor
    # -----------------------------------------------------------------------

    def test_sm2_ease_floor_on_wrong(self) -> None:
        """Ease factor never goes below 1.3, even after repeated wrong answers."""
        # Start at the floor
        new_ease, _, _, _ = calculate_sm2(
            quality=1,
            ease_factor=1.3,
            interval=0,
            repetitions=0,
        )

        assert new_ease == pytest.approx(1.3)

    def test_sm2_ease_floor_gradual_approach(self) -> None:
        """Multiple wrong answers clamp ease at 1.3, not below."""
        ease = 1.35
        for _ in range(5):
            ease, _, _, _ = calculate_sm2(
                quality=1,
                ease_factor=ease,
                interval=0,
                repetitions=0,
            )

        assert ease >= 1.3

    # -----------------------------------------------------------------------
    # Ease recovery after wrong
    # -----------------------------------------------------------------------

    def test_sm2_ease_recovery_after_wrong(self) -> None:
        """Correct answers after a wrong answer gradually restore ease above 1.3."""
        # Knock ease to floor
        ease_after_wrong, _, _, _ = calculate_sm2(
            quality=1,
            ease_factor=1.3,
            interval=0,
            repetitions=0,
        )
        assert ease_after_wrong == pytest.approx(1.3)

        # Each correct answer increases ease by 0.1
        ease_after_first_correct, _, _, _ = calculate_sm2(
            quality=3,
            ease_factor=ease_after_wrong,
            interval=0,
            repetitions=0,
        )
        assert ease_after_first_correct == pytest.approx(1.4)

        ease_after_second_correct, _, _, _ = calculate_sm2(
            quality=3,
            ease_factor=ease_after_first_correct,
            interval=1,
            repetitions=1,
        )
        assert ease_after_second_correct == pytest.approx(1.5)

    # -----------------------------------------------------------------------
    # Status transitions
    # -----------------------------------------------------------------------

    def test_sm2_status_transitions_new_to_known(self) -> None:
        """Status goes from new toward known with correct reviews (1–4 reps)."""
        ease = self.DEFAULT_EASE
        interval = self.DEFAULT_INTERVAL
        reps = self.DEFAULT_REPETITIONS

        for _ in range(1, 5):  # reviews 1–4 → should be KNOWN
            ease, interval, reps, status = calculate_sm2(
                quality=3,
                ease_factor=ease,
                interval=interval,
                repetitions=reps,
            )

        assert status == VocabularyStatus.KNOWN

    def test_sm2_status_mastered_at_five_reps(self) -> None:
        """Status becomes MASTERED after 5 consecutive correct reviews."""
        ease = self.DEFAULT_EASE
        interval = self.DEFAULT_INTERVAL
        reps = self.DEFAULT_REPETITIONS

        final_status = VocabularyStatus.NEW
        for _ in range(5):
            ease, interval, reps, final_status = calculate_sm2(
                quality=3,
                ease_factor=ease,
                interval=interval,
                repetitions=reps,
            )

        assert final_status == VocabularyStatus.MASTERED
        assert reps == 5

    def test_sm2_wrong_after_mastered_resets_to_learning(self) -> None:
        """Getting a card wrong after reaching MASTERED resets it to LEARNING."""
        # Simulate 5 correct reviews to reach MASTERED state
        ease = self.DEFAULT_EASE
        interval = self.DEFAULT_INTERVAL
        reps = self.DEFAULT_REPETITIONS

        for _ in range(5):
            ease, interval, reps, _ = calculate_sm2(
                quality=3,
                ease_factor=ease,
                interval=interval,
                repetitions=reps,
            )

        # Now answer wrong
        _, new_interval, new_reps, new_status = calculate_sm2(
            quality=1,
            ease_factor=ease,
            interval=interval,
            repetitions=reps,
        )

        assert new_status == VocabularyStatus.LEARNING
        assert new_reps == 0
        assert new_interval == 0


# ===========================================================================
# Schema validation unit tests
# ===========================================================================


class TestFlashcardReviewRequestSchema:
    """Validate the FlashcardReviewRequest Pydantic schema."""

    def test_quality_1_is_valid(self) -> None:
        """quality=1 (wrong) passes validation."""
        req = FlashcardReviewRequest(quality=1)
        assert req.quality == 1

    def test_quality_3_is_valid(self) -> None:
        """quality=3 (right) passes validation."""
        req = FlashcardReviewRequest(quality=3)
        assert req.quality == 3

    def test_quality_2_is_valid_per_schema(self) -> None:
        """quality=2 is within ge=1, le=3 bounds — schema accepts it."""
        req = FlashcardReviewRequest(quality=2)
        assert req.quality == 2

    def test_quality_0_fails_validation(self) -> None:
        """quality below 1 is rejected with ValidationError."""
        with pytest.raises(ValidationError):
            FlashcardReviewRequest(quality=0)

    def test_quality_4_fails_validation(self) -> None:
        """quality above 3 is rejected with ValidationError."""
        with pytest.raises(ValidationError):
            FlashcardReviewRequest(quality=4)

    def test_response_time_ms_optional(self) -> None:
        """response_time_ms is optional and defaults to None."""
        req = FlashcardReviewRequest(quality=3)
        assert req.response_time_ms is None

    def test_response_time_ms_non_negative(self) -> None:
        """response_time_ms must be >= 0."""
        req = FlashcardReviewRequest(quality=3, response_time_ms=500)
        assert req.response_time_ms == 500

    def test_response_time_ms_negative_fails(self) -> None:
        """Negative response_time_ms is rejected with ValidationError."""
        with pytest.raises(ValidationError):
            FlashcardReviewRequest(quality=3, response_time_ms=-1)


# ===========================================================================
# Enum value tests
# ===========================================================================


class TestEnumValues:
    """Verify enum string values match the spec."""

    def test_vocabulary_status_values(self) -> None:
        assert VocabularyStatus.NEW == "new"
        assert VocabularyStatus.LEARNING == "learning"
        assert VocabularyStatus.KNOWN == "known"
        assert VocabularyStatus.MASTERED == "mastered"

    def test_vocabulary_status_ordering(self) -> None:
        """Four distinct statuses exist."""
        assert len(VocabularyStatus) == 4


# ===========================================================================
# Endpoint integration tests
# ===========================================================================


async def _setup_user_with_language(
    client: AsyncClient,
    language: str = "es",
    cefr_level: str = "B1",
) -> str:
    """Create user + active language; return the user_language id."""
    await client.get("/v1/me")
    resp = await client.post(
        "/v1/me/languages",
        json={"target_language": language, "cefr_level": cefr_level, "interests": []},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _create_vocab_item(
    client: AsyncClient,
    text: str = "hola",
    translation: str = "hello",
    language: str = "es",
) -> str:
    """Create a vocabulary item and return its id."""
    resp = await client.post(
        "/v1/vocabulary",
        json={"text": text, "translation": translation, "language": language},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


# ---------------------------------------------------------------------------
# GET /v1/flashcards/due
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_due_cards_empty(client: AsyncClient) -> None:
    """GET /v1/flashcards/due returns an empty list when no cards exist."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/flashcards/due")

    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["total_due"] == 0


@pytest.mark.anyio
async def test_get_due_cards_includes_new_cards(client: AsyncClient) -> None:
    """GET /v1/flashcards/due (daily mode) includes new cards with no review date."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "gato", "cat")

    resp = await client.get("/v1/flashcards/due?mode=daily")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_due"] == 1
    assert body["items"][0]["text"] == "gato"


@pytest.mark.anyio
async def test_get_due_cards_count_only(client: AsyncClient) -> None:
    """GET /v1/flashcards/due?count_only=true returns FlashcardDueCountResponse."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "perro", "dog")

    resp = await client.get("/v1/flashcards/due?count_only=true")

    assert resp.status_code == 200
    body = resp.json()
    assert "count" in body
    assert body["count"] >= 1


@pytest.mark.anyio
async def test_get_due_cards_requires_active_language(client: AsyncClient) -> None:
    """GET /v1/flashcards/due returns 400 when no active language is set."""
    await client.get("/v1/me")  # Create user without language

    resp = await client.get("/v1/flashcards/due")

    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.anyio
async def test_get_due_cards_invalid_mode(client: AsyncClient) -> None:
    """GET /v1/flashcards/due with an invalid mode returns 422."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/flashcards/due?mode=invalid_mode")

    assert resp.status_code == 422


@pytest.mark.anyio
async def test_get_due_cards_new_mode_only_new(client: AsyncClient) -> None:
    """GET /v1/flashcards/due?mode=new returns only cards with status=new."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "libro", "book")

    resp = await client.get("/v1/flashcards/due?mode=new")

    assert resp.status_code == 200
    body = resp.json()
    for item in body["items"]:
        assert item["status"] == "new"


# ---------------------------------------------------------------------------
# POST /v1/flashcards/{item_id}/review
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_review_flashcard_correct(client: AsyncClient) -> None:
    """POST /v1/flashcards/{id}/review with quality=3 updates SM-2 values."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "mesa", "table")

    resp = await client.post(
        f"/v1/flashcards/{item_id}/review",
        json={"quality": 3},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["repetitions"] == 1
    assert body["interval"] == 1
    assert body["times_reviewed"] == 1
    assert body["times_correct"] == 1
    assert "review_event_id" in body


@pytest.mark.anyio
async def test_review_flashcard_wrong(client: AsyncClient) -> None:
    """POST .../review with quality=1 resets interval and repetitions to 0."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "silla", "chair")

    resp = await client.post(
        f"/v1/flashcards/{item_id}/review",
        json={"quality": 1},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["repetitions"] == 0
    assert body["interval"] == 0
    assert body["status"] == "learning"
    assert body["times_reviewed"] == 1
    assert body["times_correct"] == 0


@pytest.mark.anyio
async def test_review_flashcard_not_found(client: AsyncClient) -> None:
    """POST /v1/flashcards/{id}/review returns 404 for unknown item id."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000099"
    resp = await client.post(
        f"/v1/flashcards/{fake_id}/review",
        json={"quality": 3},
    )

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "VOCABULARY_NOT_FOUND"


@pytest.mark.anyio
async def test_review_flashcard_invalid_quality(client: AsyncClient) -> None:
    """POST /v1/flashcards/{id}/review returns 422 for out-of-range quality."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "ventana", "window")

    resp = await client.post(
        f"/v1/flashcards/{item_id}/review",
        json={"quality": 5},
    )

    assert resp.status_code == 422


@pytest.mark.anyio
async def test_review_flashcard_with_response_time(client: AsyncClient) -> None:
    """POST /v1/flashcards/{id}/review records response_time_ms."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "puerta", "door")

    resp = await client.post(
        f"/v1/flashcards/{item_id}/review",
        json={"quality": 3, "response_time_ms": 1200},
    )

    assert resp.status_code == 200
    # review_event_id confirms the event was persisted
    assert "review_event_id" in resp.json()


@pytest.mark.anyio
async def test_review_flashcard_sequential_advances_sm2(client: AsyncClient) -> None:
    """Three consecutive correct reviews advance interval: 1 → 6 → round(6*ease)."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "agua", "water")

    # Review 1
    r1 = await client.post(f"/v1/flashcards/{item_id}/review", json={"quality": 3})
    assert r1.status_code == 200
    assert r1.json()["interval"] == 1

    # Review 2
    r2 = await client.post(f"/v1/flashcards/{item_id}/review", json={"quality": 3})
    assert r2.status_code == 200
    assert r2.json()["interval"] == 6

    # Review 3 — interval = round(6 * ease_after_r2)
    ease_after_r2 = r2.json()["ease_factor"]
    r3 = await client.post(f"/v1/flashcards/{item_id}/review", json={"quality": 3})
    assert r3.status_code == 200
    assert r3.json()["interval"] == round(6 * ease_after_r2)


# ---------------------------------------------------------------------------
# POST /v1/flashcards/sessions
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_create_study_session(client: AsyncClient) -> None:
    """POST /v1/flashcards/sessions creates a session and returns 201."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily", "card_limit": 10},
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["mode"] == "daily"
    assert body["card_limit"] == 10
    assert body["total_cards"] == 0
    assert body["completed_at"] is None
    assert "id" in body


@pytest.mark.anyio
async def test_create_study_session_requires_active_language(
    client: AsyncClient,
) -> None:
    """POST /v1/flashcards/sessions returns 400 without an active language."""
    await client.get("/v1/me")

    resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily"},
    )

    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.anyio
async def test_create_study_session_invalid_mode(client: AsyncClient) -> None:
    """POST /v1/flashcards/sessions returns 422 for an invalid mode value."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "unknown_mode"},
    )

    assert resp.status_code == 422


@pytest.mark.anyio
async def test_create_study_session_card_limit_bounds(client: AsyncClient) -> None:
    """POST /v1/flashcards/sessions returns 422 when card_limit exceeds 100."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily", "card_limit": 101},
    )

    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# GET /v1/flashcards/sessions
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_study_sessions_empty(client: AsyncClient) -> None:
    """GET /v1/flashcards/sessions returns an empty list for a new user."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/flashcards/sessions")

    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["next_cursor"] is None


@pytest.mark.anyio
async def test_list_study_sessions_returns_created(client: AsyncClient) -> None:
    """GET /v1/flashcards/sessions returns previously created sessions."""
    await _setup_user_with_language(client)

    await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily", "card_limit": 5},
    )
    await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "random", "card_limit": 15},
    )

    resp = await client.get("/v1/flashcards/sessions")

    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 2


# ---------------------------------------------------------------------------
# GET /v1/flashcards/sessions/{session_id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_study_session_detail(client: AsyncClient) -> None:
    """GET /v1/flashcards/sessions/{id} returns the session with cards list."""
    await _setup_user_with_language(client)

    create_resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "hardest"},
    )
    session_id = create_resp.json()["id"]

    resp = await client.get(f"/v1/flashcards/sessions/{session_id}")

    assert resp.status_code == 200
    body = resp.json()
    assert body["id"] == session_id
    assert body["mode"] == "hardest"
    assert isinstance(body["cards"], list)


@pytest.mark.anyio
async def test_get_study_session_not_found(client: AsyncClient) -> None:
    """GET /v1/flashcards/sessions/{id} returns 404 for an unknown session."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000001"
    resp = await client.get(f"/v1/flashcards/sessions/{fake_id}")

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "SESSION_NOT_FOUND"


# ---------------------------------------------------------------------------
# PATCH /v1/flashcards/sessions/{session_id} — Complete session
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_complete_study_session(client: AsyncClient) -> None:
    """PATCH /v1/flashcards/sessions/{id} marks session completed."""
    await _setup_user_with_language(client)

    create_resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily"},
    )
    session_id = create_resp.json()["id"]

    resp = await client.patch(
        f"/v1/flashcards/sessions/{session_id}",
        json={"duration_seconds": 300},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["duration_seconds"] == 300
    assert body["completed_at"] is not None


@pytest.mark.anyio
async def test_complete_study_session_not_found(client: AsyncClient) -> None:
    """PATCH /v1/flashcards/sessions/{id} returns 404 for unknown session."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000002"
    resp = await client.patch(
        f"/v1/flashcards/sessions/{fake_id}",
        json={"duration_seconds": 120},
    )

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "SESSION_NOT_FOUND"


@pytest.mark.anyio
async def test_complete_study_session_negative_duration(client: AsyncClient) -> None:
    """PATCH /v1/flashcards/sessions/{id} returns 422 for negative duration."""
    await _setup_user_with_language(client)

    create_resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily"},
    )
    session_id = create_resp.json()["id"]

    resp = await client.patch(
        f"/v1/flashcards/sessions/{session_id}",
        json={"duration_seconds": -1},
    )

    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# POST /v1/flashcards/sessions/{session_id}/restudy
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_restudy_session_no_missed_cards_returns_404(
    client: AsyncClient,
) -> None:
    """POST /v1/flashcards/sessions/{id}/restudy returns 404 when no missed cards."""
    await _setup_user_with_language(client)

    create_resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily"},
    )
    session_id = create_resp.json()["id"]

    resp = await client.post(f"/v1/flashcards/sessions/{session_id}/restudy")

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "NO_MISSED_CARDS"


@pytest.mark.anyio
async def test_restudy_session_with_missed_cards_creates_new_session(
    client: AsyncClient,
) -> None:
    """POST .../restudy creates a new session from wrong answers in the original."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "noche", "night")

    # Create a session
    session_resp = await client.post(
        "/v1/flashcards/sessions",
        json={"mode": "daily"},
    )
    session_id = session_resp.json()["id"]

    # Submit a wrong answer linked to the session
    await client.post(
        f"/v1/flashcards/{item_id}/review?session_id={session_id}",
        json={"quality": 1},
    )

    # Restudy should now create a new session
    resp = await client.post(f"/v1/flashcards/sessions/{session_id}/restudy")

    assert resp.status_code == 201
    body = resp.json()
    assert "id" in body
    # New session id should be different from the original
    assert body["id"] != session_id


# ---------------------------------------------------------------------------
# GET /v1/flashcards/stats
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_flashcard_stats_structure(client: AsyncClient) -> None:
    """GET /v1/flashcards/stats returns all expected top-level keys."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/flashcards/stats")

    assert resp.status_code == 200
    body = resp.json()
    assert "mastery_breakdown" in body
    assert "streak_data" in body
    assert "accuracy" in body
    assert "forecast" in body
    assert "velocity" in body
    assert "time_spent" in body


@pytest.mark.anyio
async def test_get_flashcard_stats_requires_active_language(
    client: AsyncClient,
) -> None:
    """GET /v1/flashcards/stats returns 400 when no active language is set."""
    await client.get("/v1/me")

    resp = await client.get("/v1/flashcards/stats")

    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


@pytest.mark.anyio
async def test_get_flashcard_stats_forecast_has_30_days(client: AsyncClient) -> None:
    """GET /v1/flashcards/stats forecast array contains exactly 30 entries."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/flashcards/stats")

    assert resp.status_code == 200
    assert len(resp.json()["forecast"]) == 30


# ---------------------------------------------------------------------------
# GET /v1/vocabulary — List with filtering
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_vocabulary_empty(client: AsyncClient) -> None:
    """GET /v1/vocabulary returns an empty list for a new user."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/vocabulary")

    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["next_cursor"] is None


@pytest.mark.anyio
async def test_list_vocabulary_returns_created_items(client: AsyncClient) -> None:
    """GET /v1/vocabulary returns all vocabulary items the user created."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "comer", "to eat")
    await _create_vocab_item(client, "dormir", "to sleep")

    resp = await client.get("/v1/vocabulary")

    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 2


@pytest.mark.anyio
async def test_list_vocabulary_filter_by_status(client: AsyncClient) -> None:
    """GET /v1/vocabulary?status=new returns only new items."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "correr", "to run")

    resp = await client.get("/v1/vocabulary?status=new")

    assert resp.status_code == 200
    for item in resp.json()["items"]:
        assert item["status"] == "new"


@pytest.mark.anyio
async def test_list_vocabulary_search(client: AsyncClient) -> None:
    """GET /v1/vocabulary?search=... filters by text prefix match."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "ciudad", "city")
    await _create_vocab_item(client, "campo", "countryside")

    resp = await client.get("/v1/vocabulary?search=ciu")

    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["text"] == "ciudad"


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/stats
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_vocabulary_stats_zero_for_new_user(client: AsyncClient) -> None:
    """GET /v1/vocabulary/stats returns all zeros for a fresh user."""
    await _setup_user_with_language(client)

    resp = await client.get("/v1/vocabulary/stats")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 0
    assert body["new"] == 0


@pytest.mark.anyio
async def test_vocabulary_stats_increments_on_create(client: AsyncClient) -> None:
    """GET /v1/vocabulary/stats reflects newly created vocabulary items."""
    await _setup_user_with_language(client)
    await _create_vocab_item(client, "sol", "sun")

    resp = await client.get("/v1/vocabulary/stats")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert body["new"] == 1


# ---------------------------------------------------------------------------
# PATCH /v1/vocabulary/{item_id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_vocabulary_item_translation(client: AsyncClient) -> None:
    """PATCH /v1/vocabulary/{id} updates the translation field."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "lluvia", "rain")

    resp = await client.patch(
        f"/v1/vocabulary/{item_id}",
        json={"translation": "rainfall"},
    )

    assert resp.status_code == 200
    assert resp.json()["translation"] == "rainfall"


@pytest.mark.anyio
async def test_update_vocabulary_item_reset_sm2(client: AsyncClient) -> None:
    """PATCH /v1/vocabulary/{id} with reset_sm2=true restores SM-2 defaults."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "viento", "wind")

    # Do a review to advance SM-2 state
    await client.post(f"/v1/flashcards/{item_id}/review", json={"quality": 3})
    await client.post(f"/v1/flashcards/{item_id}/review", json={"quality": 3})

    # Reset
    resp = await client.patch(
        f"/v1/vocabulary/{item_id}",
        json={"reset_sm2": True},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["ease_factor"] == pytest.approx(2.5)
    assert body["interval"] == 0
    assert body["repetitions"] == 0
    assert body["status"] == "new"


@pytest.mark.anyio
async def test_update_vocabulary_item_not_found(client: AsyncClient) -> None:
    """PATCH /v1/vocabulary/{id} returns 404 for an unknown item."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000003"
    resp = await client.patch(
        f"/v1/vocabulary/{fake_id}",
        json={"translation": "something"},
    )

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "VOCABULARY_NOT_FOUND"


# ---------------------------------------------------------------------------
# POST /v1/vocabulary/batch
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_batch_create_vocabulary_happy_path(client: AsyncClient) -> None:
    """POST /v1/vocabulary/batch creates multiple items at once."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary/batch",
        json={
            "items": [
                {"text": "rojo", "translation": "red", "language": "es"},
                {"text": "azul", "translation": "blue", "language": "es"},
                {"text": "verde", "translation": "green", "language": "es"},
            ]
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["created"] == 3
    assert body["skipped"] == 0
    assert len(body["items"]) == 3


@pytest.mark.anyio
async def test_batch_create_vocabulary_skips_duplicates(client: AsyncClient) -> None:
    """POST /v1/vocabulary/batch skips items that already exist."""
    await _setup_user_with_language(client)

    # Create one item first
    await _create_vocab_item(client, "amarillo", "yellow")

    resp = await client.post(
        "/v1/vocabulary/batch",
        json={
            "items": [
                {"text": "amarillo", "translation": "yellow", "language": "es"},
                {"text": "naranja", "translation": "orange", "language": "es"},
            ]
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["created"] == 1
    assert body["skipped"] == 1


@pytest.mark.anyio
async def test_batch_create_vocabulary_empty_list_returns_422(
    client: AsyncClient,
) -> None:
    """POST /v1/vocabulary/batch returns 422 when items list is empty."""
    await _setup_user_with_language(client)

    resp = await client.post(
        "/v1/vocabulary/batch",
        json={"items": []},
    )

    assert resp.status_code == 422


@pytest.mark.anyio
async def test_batch_create_vocabulary_requires_active_language(
    client: AsyncClient,
) -> None:
    """POST /v1/vocabulary/batch returns 400 without an active language."""
    await client.get("/v1/me")

    resp = await client.post(
        "/v1/vocabulary/batch",
        json={
            "items": [
                {"text": "sol", "translation": "sun", "language": "es"},
            ]
        },
    )

    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "NO_ACTIVE_LANGUAGE"


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/{item_id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_vocabulary_item_detail(client: AsyncClient) -> None:
    """GET /v1/vocabulary/{id} returns the full item detail."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "luna", "moon")

    resp = await client.get(f"/v1/vocabulary/{item_id}")

    assert resp.status_code == 200
    body = resp.json()
    assert body["text"] == "luna"
    assert body["translation"] == "moon"
    assert "ease_factor" in body


@pytest.mark.anyio
async def test_get_vocabulary_item_not_found(client: AsyncClient) -> None:
    """GET /v1/vocabulary/{id} returns 404 for unknown item."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000004"
    resp = await client.get(f"/v1/vocabulary/{fake_id}")

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "VOCABULARY_NOT_FOUND"


# ---------------------------------------------------------------------------
# GET /v1/vocabulary/{item_id}/encounters
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_vocabulary_encounters_empty(client: AsyncClient) -> None:
    """GET /v1/vocabulary/{id}/encounters returns an empty list for new items."""
    await _setup_user_with_language(client)
    item_id = await _create_vocab_item(client, "estrella", "star")

    resp = await client.get(f"/v1/vocabulary/{item_id}/encounters")

    # Item exists but has no encounters — endpoint returns empty list
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.anyio
async def test_get_vocabulary_encounters_not_found(client: AsyncClient) -> None:
    """GET /v1/vocabulary/{id}/encounters returns 404 for unknown item."""
    await _setup_user_with_language(client)

    fake_id = "00000000-0000-0000-0000-000000000005"
    resp = await client.get(f"/v1/vocabulary/{fake_id}/encounters")

    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "VOCABULARY_NOT_FOUND"
