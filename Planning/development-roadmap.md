# LangBrew Development Roadmap

Ordered by dependency and importance. Each milestone follows: **Frontend (with mock data) → Backend → Integration → Tests → Verify & Improve**.

**Principles:**
- Build all UI for a feature first with hardcoded/mock data so you can see and feel it. Then build the backend to make it real. Then test. Then polish.
- Offline caching is added incrementally — each milestone caches what it introduces, not all-at-once at the end.
- Speaker/pronunciation buttons appear in the UI from Milestone 3 onward but remain disabled until TTS is integrated in Milestone 6. Label them "Coming soon" or hide behind a feature flag.
- Achievements are tracked incrementally as features are built, not retrofitted later.

---

## Milestone 0: Project Scaffolding & Design System

No features. Just the shell everything runs in, plus the reusable component library.

### 0.1 iOS Project Setup
- Create Xcode project (SwiftUI, iOS 18+, Swift 6)
- Configure bundle ID, signing, capabilities (Sign in with Apple, Push Notifications, In-App Purchase)
- Set up project structure: `Views/`, `Models/`, `Services/`, `Utilities/`, `Components/`, `Theme/`
- Add dependencies: `supabase-swift`, `speech-swift`
- Bundle on-device models into the app target: Qwen3-TTS (~1.0 GB), Silero VAD (~3 MB), Qwen3-ASR (~180 MB)
- Configure build schemes (Debug, Release) with separate base URLs
- Create `APIClient` service with base URL config + JWT header injection
- Create `AuthManager` wrapping supabase-swift for token storage + refresh
- Set up Core Data stack with empty schema (will be populated incrementally per milestone)
- Verify: app builds, launches to blank screen, models load without crash

### 0.2 SwiftUI Design System & Component Library
Build reusable components matching `components.html` design system before any feature screens:
- **Theme:** Color palette (linen cream `#f3f0ea`, brown-black `#2a2318`, highlight yellow `#ede8d2`), typography (Instrument Serif for headlines, Instrument Sans for UI)
- **Components:** Rounded card (12px radius, subtle shadow), pill/tag (filter pills, CEFR badges), bottom sheet wrapper, tab bar, progress bar, streak dots, stat card, avatar circle, flag emoji mapper
- **Patterns:** List row template, grid card template, empty state template, loading skeleton template, error state template
- Verify: render a test screen showing all components with mock data

### 0.3 Backend Project Setup
- Create FastAPI project: `app/main.py`, `app/core/config.py`, `app/core/auth.py`
- Dependencies: fastapi, uvicorn, sqlalchemy[asyncio], asyncpg, pyjwt, httpx, sse-starlette, arq, boto3
- `Dockerfile` (python:3.12-slim + uvicorn)
- `alembic/` with migration config pointing to Supabase Postgres
- `.env` / config: SUPABASE_JWT_SECRET, OPENROUTER_API_KEY, MISTRAL_API_KEY, DATABASE_URL, REDIS_URL, R2 credentials
- `GET /v1/health` endpoint (checks DB + Redis)
- Supabase JWT verification middleware (`app/core/auth.py`)
- Standard error response format (Pydantic model)
- Deploy to Supabase: connect GitHub, set env vars, auto-deploy on push
- Verify: `GET /v1/health` returns 200 from Supabase URL

### 0.4 CI/CD Pipeline
- GitHub Actions: on push to main → lint (ruff) → test (pytest) → deploy to Supabase
- Alembic migrations run on deploy
- Verify: push a change, watch auto-deploy, health check passes

### 0.5 Supabase Auth Setup
- Create Supabase project
- Enable Apple Sign-In, Google Sign-In, email/password with verification
- Note JWT secret → add to backend env vars
- Verify: create test user from dashboard, confirm JWT issued

---

## Milestone 1: Authentication & Onboarding

After this, a user can sign up, complete onboarding, and land on the main app. Every subsequent milestone depends on a logged-in user.

### 1.1 Frontend — All Onboarding Screens (with mock data)
Build the entire onboarding flow as static screens first:
- **S1 (Splash):** Logo animation, fade-in, transition to Welcome
- **O1 (Welcome):** Three pillars layout, "Get Started" + "Sign in" buttons
- **C0–C5 (Carousel):** 6 static educational screens with dot indicator, skip, back
- **O2 (Language Selection):** Grid of 8 flag cards. Store selection locally (UserDefaults).
- **O3 (Proficiency Level):** A1–C1 vertical list with descriptions. Store locally.
- **O4 (Interests):** Topic pill grid, minimum 3 required, "5 selected · 3 minimum" counter. Categories: Lifestyle, Knowledge, Entertainment. Store locally.
- **O5 (Daily Goal):** 4 goal cards (5/10/20/30 min), streak preview dots. Store locally.
- **O6 (Account Setup):** Apple / Google / email buttons (wired to Supabase). On auth success, proceed to O6b.
- **O6b (Choose Plan):** Monthly/Yearly toggle, Fluency ($72/yr) vs Free cards, "Start Free Trial" button. For now, always select Free (StoreKit integration is Milestone 10). Store selection locally.
- **O7 (First Passage):** "You're all set" celebration screen with placeholder passage card. "Start Learning" → navigate to Home tab. "Explore the app first" → navigate to Home tab.
- **L1 (Log In):** "Welcome back" + Apple/Google/email. On success → skip onboarding → Home.
- Wire navigation: S1 → O1 → C0–C5 → O2 → O3 → O4 → O5 → O6 → O6b → O7 → Home
- Wire L1 → Home (for returning users)
- Request notification permission after O6 (for best opt-in rates)

### 1.2 Backend — User, Settings, Language Tables & Endpoints
- **Migrations:** Create `users`, `user_settings`, `user_languages`, `device_tokens`, `usage_meters`
- **`GET /v1/me`** — Auto-create user + default settings on first call. Return profile + active language + settings.
- **`PATCH /v1/me`** — Update name, daily_goal_minutes, new_words_per_day, auto_adjust_difficulty, timezone, onboarding_step, onboarding_completed
- **`PATCH /v1/me/settings`** — Update all 22 settings fields
- **`POST /v1/me/avatar`** — Multipart → R2 → update avatar_url
- **`POST /v1/me/languages`** — Create user_language. Set as active.
- **`GET /v1/me/languages`** — List with levels, interests, active flag
- **`PATCH /v1/me/languages/:id`** — Update CEFR, interests, set active
- **`DELETE /v1/me/languages/:id`** — Remove language
- **`POST /v1/me/devices`** — Register APNs token
- **`DELETE /v1/me/devices/:token`** — Unregister
- **`GET /v1/me/usage`** — Current period usage vs limits. Auto-create usage_meter if none.

### 1.3 Integration — Connect Onboarding to Backend
- After Supabase auth: call `GET /v1/me` (auto-create)
- Call `POST /v1/me/languages` with O2 + O3 + O4 selections
- Call `PATCH /v1/me` with daily_goal, onboarding_step=8, onboarding_completed=true
- Register device token via `POST /v1/me/devices`
- Handle resume: check `onboarding_step` from `GET /v1/me`, resume at correct screen
- Handle returning users: `onboarding_completed == true` → skip to Home

### 1.4 Tests
- Backend: user auto-creation, PATCH validation, language CRUD, duplicate language rejection, usage_meter auto-creation
- Frontend: full onboarding completion, Apple sign-in (simulator), resume from mid-onboarding
- Integration: sign up → complete onboarding → verify all records in Supabase Postgres

### 1.5 Verify & Improve
- Sign up with Apple, Google, and email on real device
- Complete full onboarding flow end-to-end
- Kill app mid-onboarding, reopen — resumes correctly
- Sign out, sign back in — data persists, skips to Home
- Check Supabase for correct records

---

## Milestone 2: Home Screen, Navigation Shell & Basic Settings

The app needs a place to land. Build the tab bar, home screen, and a basic settings shell so the user can see their profile and change preferences from here on.

### 2.1 Frontend — Tab Bar, Home Screen & Settings Shell (with mock data)
- **Bottom tab bar:** Home, Library, Talk, Flashcards (icons + labels)
- **Home screen (screen 1):**
  - Greeting: "Good morning, {name}" + language switcher flag + profile avatar
  - Streak: fire emoji + count + 7 day dots
  - Quick action cards: "Chat with Mia" + "X cards due" (non-functional, tap shows "Coming soon")
  - Today's Passage card — empty state: "Generate your first passage" CTA
  - Currently Reading — empty state: "Import your first book"
  - Recent Books row — hidden when empty
  - Word Progress: Words (0) / Learning (0) / Mastered (0), "View all stats →"
  - Profile avatar tap → Settings
- **Language switcher:** Tap flag → show language picker sheet → `PATCH /v1/me/languages/:id` to set active → refresh Home data
- **Settings shell (screen 7):** Build the full settings layout with all sections. All toggles and tappable rows are wired to `PATCH /v1/me` or `PATCH /v1/me/settings`. Sub-screens that depend on later milestones (subscription, delete account, help center) show placeholder text.
- **Edit Account (screen 7b):** Avatar change, name edit, read-only email
- **Daily Goal Editor (screen 7-goal):** 4 goal cards → `PATCH /v1/me`

### 2.2 Backend — Home Aggregation
- **`GET /v1/home`** — Aggregated response:
  - user: name, avatar_url, current_streak, streak_week (7 bools)
  - cards_due: 0 (no vocabulary yet)
  - todays_passage: null
  - current_book: null
  - recent_books: []
  - word_stats: { total: 0, learning: 0, mastered: 0 }

### 2.3 Integration — Wire Home & Settings to Backend
- Replace mock data with `GET /v1/home`
- Empty states render when data is null/empty
- Pull-to-refresh on Home
- Settings changes persist via PATCH endpoints
- Language switcher updates active language → refreshes Home

### 2.4 Tests
- Backend: /v1/home shape for new user, settings round-trips
- Frontend: Home renders with empty state, language switcher works, settings persist across restarts

### 2.5 Verify & Improve
- Onboarding → Home → all sections render with empty states
- Change daily goal in Settings → verify it persists
- Switch active language → Home greeting flag changes
- Pull-to-refresh works

---

## Milestone 3: Passage Generation & Reader

The first core learning feature. After this, the user can generate a passage, read it, tap words for definitions, and start building their vocabulary.

### 3.1 Frontend — Library (Passages Tab) & Generation UI (with mock data)
- **Library tab:** Two sub-tabs: Passages / My Books (My Books is empty placeholder for now)
- **Passages grid (screen 2a):** Empty state → "Generate your first passage" CTA
- **Generate bottom sheet (screen 2a-gen):**
  - Auto / Custom mode toggle
  - Auto: suggested topic pills from user's interests, "Generate" button
  - Custom: topic input, style (Article/Dialogue/Story/Letter), length (Short/Medium/Long), difficulty (A1–C1), "Generate" button
- **Loading screen (L0):** Floating words animation, rotating status messages
- **Mock a passage card** in the grid to build the card layout: title, CEFR badge, word count, time, excerpt, "AI" badge, progress bar

### 3.2 Frontend — Reader View & Word Interactions (with mock data)
- **Reader (screen 4a):** Top nav (back, title, listening icon [disabled], text options icon), passage body in serif font, highlighted vocabulary words (cream bg + dotted underline), scroll-tracked reading progress
- **Text Options (screen 4e):** Font size slider, line spacing, serif/sans, light/sepia/dark theme. Save → `PATCH /v1/me/settings`. This is a reader feature, not a TTS feature.
- **Word tap (screen 4b):** Bottom sheet with word, phonetic, word type, definition, example sentence, speaker button [disabled until TTS], "Add to Language Bank" / undo
- **Word long press (screen 4c):** Extended definitions view
- **Phrase selection (screen 4c2):** Drag-select → translation popup, "Save Phrase" button
- Use mock passage data to build and polish all these screens before any backend

### 3.3 Backend — AI Service, Passage Generation & Vocabulary
- **Migrations:** Create `passages`, `passage_vocabulary`, `vocabulary_items`, `vocabulary_encounters`
- **`app/services/ai_service.py`** — OpenRouter client with config-based model routing, SSE streaming proxy, Pydantic validation
- **`app/middleware/usage_meter.py`** — Check tier limits before AI calls, return 402
- **`app/middleware/rate_limit.py`** — Redis sliding window
- **`POST /v1/passages/generate`** — SSE: check usage → sanitize → build prompt (CEFR, interests, topic, style, length, known vocabulary sample) → stream → parse JSON → store passage + passage_vocabulary (with definitions, phonetics, word types) → cross-reference highlights → increment meter
- **`GET /v1/passages`** — List with ?search, ?cefr_level, ?topic, ?is_generated, ?sort_by, ?sort_order, cursor pagination
- **`GET /v1/passages/:id`** — Full passage + vocabulary annotations
- **`PATCH /v1/passages/:id`** — Update reading_progress, bookmark_position
- **`DELETE /v1/passages/:id`** — Soft delete
- **`POST /v1/vocabulary/define`** — Redis cache → MiMo Flash → cache 30d → return
- **`POST /v1/vocabulary/translate`** — Redis cache → MiMo Flash → cache 7d → increment translations_used → return
- **`POST /v1/vocabulary`** — Create vocabulary_item + vocabulary_encounter. SM-2 defaults.
- **`DELETE /v1/vocabulary/:id`** — Remove (undo)

### 3.4 Integration — Connect All Screens to Backend
- Generation flow: tap Generate → show loading → SSE streams → navigate to Reader
- Passage appears in Library grid
- Word tap → show definition from passage_vocabulary data (no LLM call needed for generated passages)
- Word long press → `POST /v1/vocabulary/define` if not in passage_vocabulary cache
- Phrase selection → `POST /v1/vocabulary/translate`
- "Add to Language Bank" → `POST /v1/vocabulary`
- Reading progress auto-saved on scroll
- Search bar, filter pills, sort on passages list
- 402 error → show "Upgrade" bottom sheet (links to placeholder subscription screen)
- **Offline caching:** Cache fetched passages + vocabulary in Core Data. Reading a cached passage works offline. Progress changes queued locally.

### 3.5 Tests
- Backend: SSE streaming, vocabulary creation, Redis caching, usage meter enforcement, rate limiting, passage search/filter
- Frontend: generation flow, word tap, phrase translation, reading progress, offline cache
- AI quality: generate 3 passages per language at A1 and B1. Evaluate readability, vocab accuracy, JSON validity.

### 3.6 Verify & Improve
- Generate passages in all 8 languages — check grammar, naturalness, difficulty
- Tap 10 words — definitions accurate and context-appropriate?
- Select 3 phrases — translations natural?
- Read passage, close app, reopen — progress saved?
- Exhaust free tier (10 passages) — 402 + upgrade prompt?
- Switch to airplane mode, open a cached passage — can still read it?
- If MiMo quality is insufficient for any language, swap passage_generation to Gemma 4 in config.

---

## Milestone 4: Language Bank & Flashcards

Words added during reading become reviewable. This completes the core learning loop: Read → Add Words → Review.

**Moved ahead of TTS because flashcard review is the core retention mechanism. Without it, words added in Milestone 3 have no way to be reinforced.**

### 4.1 Frontend — Language Bank (with mock data)
- **Language Bank (screen 6):** Three tabs (Words / Phrases / Sentences), header stats row, search bar, filter pills (All / New / Learning / Known / Mastered), word list with text + translation + status
- **Item detail (screen 6b):** Stats, encounter history, "Remove from Language Bank" button
- Build with mock vocabulary data

### 4.2 Frontend — Flashcard Review (with mock data)
- **Front (screen 7):** Word, language tag, speaker button [disabled], example sentence, "Tap to reveal"
- **Back (screen 8):** Translation, numbered definitions, 2 buttons: "I got it wrong" (gray) / "I got it right" (dark)
- **Progress:** X of Y indicator + progress bar
- **Custom Study (screen 5b):** Mode selector (Daily / Hardest / New / Review Ahead / Random), type filter (All / Words / Phrases / Sentences), card limit (10/25/50/All), "Start Study"
- **Past Sessions (screen 5c):** Session list grouped by date
- **Session Detail (screen 5d):** Per-card breakdown, accuracy, "Re-study Missed" button
- **Statistics (screen 5):** Streak, mastery breakdown bar, forecast calendar, learning velocity chart
- Build all screens with mock data first

### 4.3 Backend — Language Bank & Flashcard Engine
- **Migrations:** Create `review_events`, `study_sessions`, `session_reviews`
- **`GET /v1/vocabulary`** — Paginated + ?search, ?type, ?status, ?language
- **`GET /v1/vocabulary/stats`** — Aggregate counts by status/type + due_for_review
- **`GET /v1/vocabulary/:id`** — Full detail with SM-2 stats + accuracy
- **`POST /v1/vocabulary/batch`** — Batch create (for book processing later)
- **`PATCH /v1/vocabulary/:id`** — Update status, context reset
- **`GET /v1/vocabulary/:id/encounters`** — Encounter history
- **`GET /v1/flashcards/due`** — 5 modes (daily/hardest/new/ahead/random) + ?type + ?count_only
- **`POST /v1/flashcards/:id/review`** — SM-2 algorithm, status transitions, create review_event + session_review, update streak
- **`POST /v1/flashcards/sessions`** — Create session
- **`GET /v1/flashcards/sessions`** — Past sessions paginated
- **`GET /v1/flashcards/sessions/:id`** — Detail with per-card breakdown
- **`PATCH /v1/flashcards/sessions/:id`** — Complete session
- **`POST /v1/flashcards/sessions/:id/restudy`** — Restudy missed cards
- **`GET /v1/flashcards/stats`** — Mastery breakdown, forecast, velocity (cached in Redis 1h)
- **Learning steps:** Client manages 1min/10min re-shows within session. Server just receives the review events.

### 4.4 Integration — Wire Language Bank & Flashcards to Backend
- Language Bank populates from vocabulary_items created during reading
- Flashcard tab shows "X cards due" badge from `GET /v1/flashcards/due?count_only=true`
- Home screen "X cards due" quick action now works
- Full review flow: load → flip → rate → next card → complete session
- Custom study modes all functional
- Past sessions list and detail with re-study
- Stats screen with live data
- **Offline caching:** Cache vocabulary_items in Core Data. Flashcard reviews work offline (store review_events locally, queue for sync).
- **Home screen updates:** `GET /v1/home` now returns real cards_due count and word_stats

### 4.5 Tests
- SM-2: both quality mappings (wrong=1, right=3), interval progressions, learning steps, context reset, ease recovery, status transitions
- Sessions: create/complete/restudy lifecycle, per-card breakdown
- Stats: mastery counts, forecast, Redis caching
- Frontend: full review flow, learning step re-shows, offline review queueing

### 4.6 Verify & Improve
- Add 20 words during reading → review them all → intervals make sense?
- Review across multiple days → spacing increases?
- "Again" 3 times → card appears more frequently?
- Complete session → detail shows correct accuracy and breakdown?
- Re-study missed → only failed cards appear?
- Forecast calendar reflects actual due dates?
- Go offline → review 5 cards → come back online → verify queued locally (full sync in Milestone 11)

---

## Milestone 5: AI Conversation (Talk)

The second core pillar. Users can have text and voice conversations with AI partners.

### 5.1 Frontend — Chat History & New Conversation (with mock data)
- **Talk tab → Chat History (screen 3b):** "New Chat" button, conversation list (avatar, topic, preview, timestamp, unread badge)
- **New Conversation (screen 3b-ii):** Partner selector (6 avatars), topic grid (9 presets + emoji), refresh button, custom topic input, "Start conversation" button
- Build with mock conversation data

### 5.2 Frontend — Chat Interface (with mock data)
- **Chat (screen 3a):** AI bubbles (left, light), user bubbles (right, dark), text input bar ("Type or tap to speak" + mic/send toggle)
- Mock a multi-message conversation to build the layout
- Voice message display: waveform placeholder + play button + duration + "See translation"

### 5.3 Frontend — Feedback Screen (with mock data)
- **Feedback (screen 3c):** Overall score ring, skill bars (Grammar/Vocabulary/Speaking/Listening), "What you did well", corrections cards, "Tip for next time", "Done" button
- Build with mock feedback data

### 5.4 Backend — Conversation, Partners, Chat Streaming, Transcription, Feedback
- **Migrations:** Create `conversation_partners` (seed 6 characters), `conversations`, `messages`, `conversation_feedback`
- **`GET /v1/talk/partners`** — All 6 partners with metadata + voice_config
- **`POST /v1/talk/conversations`** — Create conversation. Check usage meter (talk_seconds).
- **`GET /v1/talk/conversations`** — List with preview, timestamp, unread. Paginated.
- **`GET /v1/talk/conversations/:id`** — Metadata + messages. Set has_unread=false.
- **`POST /v1/talk/conversations/:id/messages`** — SSE: store user message → build prompt (partner personality + history + CEFR) → stream MiMo → store AI message → update preview/timestamp/unread
- **`POST /v1/talk/transcribe`** — Forward audio to Voxtral Realtime → return text + confidence
- **`POST /v1/talk/conversations/:id/end`** — End conversation, queue feedback job
- **`GET /v1/talk/conversations/:id/feedback`** — Return feedback (202 if generating)
- **`DELETE /v1/talk/conversations/:id`** — Delete
- **`app/jobs/feedback.py`** — ARQ job: transcript → MiMo → structured analysis → store feedback → extract vocabulary
- **`app/jobs/cleanup.py`** — Abandoned conversation cleanup (30 min inactivity)

### 5.5 Integration — Wire Chat to Backend
- Text messaging: type → send → SSE stream → render token by token
- Vocabulary highlighting in AI messages (cross-reference user's Language Bank)
- Voice input: integrate Silero VAD (end-of-speech detection) → record → `POST /v1/talk/transcribe` → display transcription → continue as text
- Voice message waveform display + "See translation" → `POST /v1/vocabulary/translate`
- End conversation → feedback screen (poll until ready)
- Vocabulary extracted from feedback auto-appears in Language Bank
- Home screen "Chat with Mia" quick action now works
- **Note:** AI TTS of responses is NOT wired yet — text-only output. TTS comes in Milestone 6.

### 5.6 Tests
- SSE streaming, message storage, conversation list ordering
- Voice: Voxtral round-trip in 8 languages
- Feedback: background job completes, vocabulary extraction, score structure
- Abandoned: cleanup fires after 30 min

### 5.7 Verify & Improve
- 3 conversations in Spanish at A2 — naturalness, corrections, level-appropriate?
- Voice input → transcription → AI response loop works?
- End conversation → feedback in 10-30s?
- Corrections accurate? Explanations helpful?
- Test in German and Japanese — multilingual quality?
- If chat quality poor → swap "chat" to Gemma 4 in config

---

## Milestone 6: Text-to-Speech & Listening Mode

Adds audio to reading (passage listening) and enables pronunciation throughout the app. Speaker buttons that were disabled since Milestone 3 now activate.

### 6.1 Frontend — TTS Service Integration
- Integrate speech-swift Qwen3-TTS into the app
- Create `TTSService`:
  - Split text into sentences (NLTokenizer)
  - Generate audio per sentence with user's preferred voice + speed
  - Cache generated audio locally (avoid re-synthesis)
  - Single-word pronunciation for word tap / flashcard speaker buttons

### 6.2 Frontend — Listening Mode (screen 4d)
- Toggle from reader top nav
- Controls: play/pause, rewind 30s, forward 30s, speed pill (0.5x–2.0x), progress bar (time / duration)
- **Sentence highlighting (Tier 1):** Dim all text, highlight active sentence during playback
- **Word highlighting (Tier 2):** Run Qwen3-ASR on TTS audio per sentence → word-level timestamps → highlight current word. Controlled by highlight_following setting.

### 6.3 Frontend — Voice Options (screen 4f)
- Bottom sheet: 6 voices (Mia/Carlos/Elena/Lucia/Diego/Marco) with personality tags + preview button
- Speed slider (0.5x–2.0x)
- Save → `PATCH /v1/me/settings` (preferred_voice_id, voice_speed)

### 6.4 Frontend — Enable All Speaker Buttons
- Reader word tap (screen 4b): speaker button → Qwen3-TTS single-word pronunciation
- Flashcard front (screen 7): speaker button → pronounce the word
- Talk AI responses: auto-speak completed sentences via Qwen3-TTS (optional, controlled by auto_play_audio setting)

### 6.5 Backend — Listening Time Tracking
- **Migrations:** Create `listening_sessions`
- **`POST /v1/me/usage/listening`** — Accept passage/book, language, duration. Create listening_session. Increment usage_meters.listening_seconds.

### 6.6 Integration — Listening Time Reporting
- Report listening seconds when: mode ends, user pauses, leaves screen, passage finishes
- Track locally for offline, queue for sync
- Free tier: "X listening hours remaining" on listening mode screen

### 6.7 Tests
- TTS: audio generation in all 8 languages, no crashes, acceptable quality
- Highlighting: sentence boundaries correct, word timestamps align
- Voices: all 6 generate audio, speed works
- Listening tracking: session creation, usage meter increment

### 6.8 Verify & Improve
- Listen to passages in Spanish, French, German, Japanese — voice quality natural?
- Sentence highlighting stays in sync over 5-minute passage?
- Word highlighting accuracy?
- Speed settings (0.5x, 1.0x, 1.5x, 2.0x) all work?
- Listening time correctly decrements free tier?

---

## Milestone 7: Book Import & Reading

The third content pillar. Reuses Reader View (Milestone 3) and vocabulary infrastructure (Milestone 4).

### 7.1 Frontend — My Books Tab & Import Flow (with mock data)
- **My Books (screen 2b):** Book list with cover, title, author, progress bar, CEFR badge. Filter toggles (All/Reading/Finished). "Import a book" CTA.
- **Import confirmation (screen 2b-confirm):** File details (name, size, type), content preview, copyright checkbox
- **Import progress (screen 2b-importing):** Progress bar + status messages
- Build with mock book data

### 7.2 Backend — Book Upload & Processing
- **Migrations:** Create `books`, `book_chapters`
- **`POST /v1/books/upload`** — Validate (magic bytes, 50 MB max, DRM), upload to R2, create record, queue job
- **`app/jobs/book_processing.py`** — EPUB (ebooklib), PDF (pdfplumber), TXT. Per chapter: R2 JSON, vocabulary extraction via MiMo, CEFR estimation. Progress updates throughout.
- **`GET /v1/books`** — List with ?status, ?language
- **`GET /v1/books/:id`** — Metadata + chapter list
- **`GET /v1/books/:id/status`** — Processing status + progress %
- **`GET /v1/books/:id/chapters/:n`** — Chapter content from R2 + vocabulary annotations
- **`PATCH /v1/books/:id`** — Update progress, last_read_chapter, last_read_position, last_read_at
- **`DELETE /v1/books/:id`** — Delete from Postgres + R2

### 7.3 Integration — Connect Import & Reading
- File picker → upload → poll status → library updates when ready
- Reuse Reader View: chapter navigation, word tap, listening mode, text options
- Table of Contents (screen 4a-toc): chapter list with per-chapter progress
- Home screen "Currently Reading" and "Recent Books" now populate
- Free tier: 1 book total — enforce on upload, show limit message
- **Offline caching:** Cache current chapter content in Core Data

### 7.4 Tests
- EPUB, PDF, TXT processing. DRM rejection. Oversize rejection.
- Chapter extraction, vocabulary annotations, CEFR estimation
- Chapter navigation, per-chapter progress, vocabulary highlighting

### 7.5 Verify & Improve
- Import real Spanish EPUB (~100 pages) — chapters correct? Vocabulary highlighted?
- Import PDF — text extraction quality?
- Read 2 chapters — progress saved? TOC updated?
- Tap words in book — definitions work?
- Free tier: upload 1 book, try another — blocked?

---

## Milestone 8: Statistics, Achievements & Reading Speed

Aggregates all progress data into dashboards.

### 8.1 Frontend — Statistics Screen (with mock data)
- **Statistics (screen 8):** Streak display, overview cards (Words/Passages/Chats), CEFR level + progress ring + skill breakdown, topic pills with word counts, reading speed + change indicator
- **Achievements grid:** Earned (color + date) and locked (gray + progress bar) badges
- **Language detail (screen 7a):** Per-language stats (hours, words, skills, listening stats)
- Build with mock data

### 8.2 Backend — Stats, Achievements, Reading Speed
- **Migrations:** Create `achievement_definitions` (seed 13 achievements), `achievements`, `reading_speed_logs`
- **`GET /v1/me/stats`** — Aggregate: vocabulary counts, passages, conversations, streaks, wpm + change %
- **`GET /v1/me/languages/:id/stats`** — Per-language: hours, words, skills, listening, CEFR progress, suggested_level
- **`GET /v1/me/achievements`** — All definitions + user progress. Locked and unlocked.
- **`POST /v1/me/reading-speed`** — Store measurement
- **Achievement checking:** Add hooks to review, passage completion, chat completion, book import endpoints to check thresholds and update achievements.

### 8.3 Integration
- Stats screen and achievements grid wired to live data
- Language detail in Settings now shows real per-language stats
- Reading speed reported from Reader View when user finishes/pauses a passage
- Achievement toast notification when unlocked during use
- Home "View all stats →" navigates to Statistics

### 8.4 Tests
- Aggregation accuracy, per-language filtering, achievement threshold crossing, reading speed calculation

### 8.5 Verify & Improve
- After using all features, stats accurate?
- Trigger 2-3 achievements — unlock correctly?
- Per-language stats — hours, words, skill levels accurate?
- Auto-adjust suggestion appears when threshold crossed?

---

## Milestone 9: Subscription & Billing

Turns the free/paid distinction from enforcement-only (402 errors since Milestone 3) into a real purchase flow.

### 9.1 Frontend — Subscription Screens
- **O6b (Choose Plan):** Now functional — Monthly/Yearly toggle, Fluency vs Free cards, "Start Free Trial". Integrate StoreKit 2.
- **Subscription settings (screen 7c):** Current plan badge, usage summary, "Upgrade" / "Restore Purchases"
- **Upgrade bottom sheet:** Consistent component shown on any 402 error — replaces the placeholder from Milestone 3
- Usage allowances on relevant screens ("8 passages remaining")

### 9.2 Backend — Subscription Verification & Webhooks
- **`POST /v1/me/subscription/verify`** — Validate JWS, update tier + expiry + transaction ID, log event
- **`POST /v1/me/subscription/restore`** — Re-validate existing transactions
- **`POST /v1/webhooks/appstore`** — JWS signature verification. Handle all lifecycle events. Update tier.
- **Migrations:** Create `subscription_events`

### 9.3 Integration
- StoreKit 2 purchase flow → verify on server → tier updates immediately
- All 402 errors now show the real upgrade bottom sheet
- Usage display in subscription settings
- Restore purchases works

### 9.4 Tests
- Sandbox purchase, webhook lifecycle, usage enforcement, restore

### 9.5 Verify & Improve
- Purchase in sandbox → tier updates?
- Exceed free limit → upgrade → unblocked?
- Cancel → downgrade via webhook?
- Restore on second device?

---

## Milestone 10: Offline Sync

Ties together all the incremental offline caching from earlier milestones into a coherent sync system.

### 10.1 Frontend — Complete Core Data Schema
- Finalize Core Data models mirroring: passages, vocabulary_items, review_events, user_streaks, user_settings, books/chapters
- Implement change tracking: queue all offline mutations (reviews, progress, vocabulary adds, settings changes, listening seconds)

### 10.2 Backend — Sync Endpoint
- **`POST /v1/sync`** — Full delta payload. Apply conflict resolution:
  - Review events: append, replay SM-2
  - Reading/book progress: MAX
  - Streaks: sum per date per language
  - Vocabulary: by updated_at
  - Listening: additive
  - Settings: last-write-wins

### 10.3 Integration
- Sync on: app launch, foreground return, pull-to-refresh
- Subtle sync indicator
- All queued offline changes upload on sync
- Server changes since last_synced_at download

### 10.4 Tests
- Offline flashcard review → sync on reconnect
- Two-device conflict → event-sourced reconciliation
- Offline reading → progress syncs
- Full day offline → complete sync

### 10.5 Verify & Improve
- Airplane mode → flashcards + reading → WiFi on → everything syncs?
- Two-device simulation → no data loss?
- Sync payload reasonable for 1000+ vocabulary items?

---

## Milestone 11: Push Notifications & Daily Passage

### 11.1 Backend — Notification Infrastructure & Daily Job
- Integrate aioapns
- **Notification triggers:**
  - Daily reminder: ARQ cron at user's reminder_time
  - Streak alert: evening check if no activity today
  - Review reminder: cards due + no review today
  - Book processing complete
  - Feedback ready
  - Achievement unlocked
- **`app/jobs/daily_passage.py`** — ARQ cron (4 AM per timezone): generate one passage per active user with quota. Store with is_generated=true.

### 11.2 Frontend — Notification Handling & Today's Passage
- Handle notification tap → deep link to correct screen
- Notification preferences in Settings now functional (streak_alerts, review_reminder toggles)
- `GET /v1/home` todays_passage: auto-generated → if read, fall back to most recent unread → if none, show CTA

### 11.3 Tests
- Each notification type fires at correct trigger
- Deep links work
- Preferences respected (disable → stops)
- Daily job: generates for active users, respects quota, timezone batching
- Today's passage: generated → read → fallback → CTA

### 11.4 Verify & Improve
- Daily reminder arrives at set time?
- Feedback notification after conversation?
- Book completion notification?
- Disable streak alerts → stops?
- Daily passage appears on Home next morning?

---

## Milestone 12: Account Management & Support

Complete the remaining Settings sub-screens.

### 12.1 Frontend — Remaining Settings Screens
- **Delete account (screen 7-delete):** Typed confirmation dialog → `DELETE /v1/me/account`
- **Send feedback (screen 7d):** Type selector, message, email → `POST /v1/feedback`
- **Help Center (screen 7g):** Static FAQ (bundled JSON or R2-hosted)
- **Privacy Policy (screen 7e) & Terms (screen 7f):** Web views
- **Reminder time (screen 7-reminder):** Time picker → `PATCH /v1/me/settings`
- **Sign out:** Clear Supabase session + clear Core Data cache

### 12.2 Backend — Feedback & Deletion
- **`POST /v1/feedback`** — Store feedback_submission
- **`DELETE /v1/me/account`** — Validate confirmation → cascade delete (all Supabase Postgres tables, R2 files, device tokens, Supabase admin API)
- **Migrations:** Create `feedback_submissions`

### 12.3 Tests
- Deletion cascades all records
- Feedback stored
- Sign out clears local data

### 12.4 Verify & Improve
- Delete account → all data gone from Supabase Postgres, R2?
- Submit feedback → appears in DB?
- Sign out → sign back in → data loads fresh from server?

---

## Milestone 13: Polish & Pre-Launch

### 13.1 Loading States & Transitions
- Loading screen (L0) with floating words for all async operations
- Skeleton placeholders for lists/grids while loading
- Smooth transitions between screens

### 13.2 Error Handling
- Network error states (retry button)
- Server error states (500 → "Something went wrong")
- Rate limit states (429 → "Please wait")
- Graceful JWT expiry handling

### 13.3 Edge Cases
- SSE timeout → client retry logic
- Partial passage generation (SSE drops) → cleanup + retry
- Book processing failure → error message + retry option
- Concurrent sync from multiple devices

### 13.4 Performance
- Profile Core Data for 5000+ vocabulary items
- Pre-warm Qwen3-TTS on app launch (background)
- Home screen < 1s load on real device
- Flashcard review loop: no perceptible lag between cards
- Test on iPhone 12 (oldest supported)

### 13.5 App Store Preparation
- App icon, screenshots, preview video
- App Store description, keywords, metadata
- Privacy nutrition labels
- AI-generated content disclosure
- Subscription rules compliance
- TestFlight beta

### 13.6 Final End-to-End Verification
- Complete full user journey: sign up → onboard → generate passage → read → tap words → add to bank → listen → review flashcards → have conversation → get feedback → import book → check stats → manage settings → upgrade → go offline → sync → delete account
- Test in all 8 languages
- Test offline mode end-to-end
- Load test backend: 50 concurrent users

---

## Dependency Map

```
M0 (Scaffolding)
 └─ M1 (Auth & Onboarding)
     └─ M2 (Home & Settings Shell)
         └─ M3 (Passages & Reader)
             ├─ M4 (Flashcards & Language Bank)  ← core loop completes here
             │   └─ M5 (Talk / Conversation)
             │       └─ M7 (Book Import)
             │           └─ M8 (Statistics & Achievements)
             └─ M6 (TTS & Listening Mode)  ← can run after M3, parallel to M4-M5 if desired

M8 → M9 (Subscription & Billing)
M4 → M10 (Offline Sync)
M1 → M11 (Notifications & Daily Passage)
M9 → M12 (Account Management)
All → M13 (Polish & Launch)
```

**Critical path:** M0 → M1 → M2 → M3 → M4 → M5 → M7 → M8 → M9 → M13

**Can be parallelized if resources allow:**
- M6 (TTS) can run alongside M4–M5 since it's almost entirely frontend work
- M10 (Sync) can start after M4 since vocabulary sync is the most important
- M11 (Notifications) can start anytime after M1
