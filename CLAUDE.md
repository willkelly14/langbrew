# LangBrew

Language learning iOS app built around comprehensible input: AI reading passages,
AI conversation practice, and spaced repetition flashcards.

## Stack

| Layer    | Technology                                        |
| -------- | ------------------------------------------------- |
| Frontend | Swift 6, SwiftUI, iOS 18+, supabase-swift         |
| Backend  | Python 3.12, FastAPI, uvicorn                     |
| Database | Neon Postgres (SQLAlchemy async + asyncpg)        |
| Cache    | Upstash Redis                                     |
| Auth     | Supabase Auth (Apple/Google/email)                |
| Storage  | Cloudflare R2                                     |
| AI (LLM) | MiMo v2 Flash via OpenRouter                     |
| TTS      | Qwen3-TTS 0.6B (on-device CoreML)                |
| STT      | Voxtral Realtime via Mistral                      |
| Hosting  | Railway (backend), App Store (iOS)                |

## Project structure

```
LangBrew/
  Planning/           — Product specs, backend plan, development roadmap
  backend/            — FastAPI application
    app/
      core/           — Config, auth, database, redis
      models/         — SQLAlchemy ORM models
      schemas/        — Pydantic v2 request/response models
      routers/        — FastAPI route handlers
      services/       — Business logic
      middleware/     — Usage metering, rate limiting
      jobs/           — ARQ background tasks
    alembic/          — Database migrations
    tests/            — pytest test suite
  ios/                — Xcode project
    LangBrew/
      Views/          — SwiftUI views by feature
      ViewModels/     — Observable view models
      Models/         — Codable data models
      Services/       — API client, auth, cache, sync
      Components/     — Reusable UI components
      Theme/          — Colors, typography, spacing
      Utilities/      — Extensions, helpers
```

## Commands

### Backend
```bash
cd backend && uvicorn app.main:app --reload                     # Run dev server
cd backend && python -m pytest tests/ -v                        # Run tests
cd backend && ruff check app/ tests/                            # Lint
cd backend && ruff format app/ tests/                           # Format
cd backend && alembic upgrade head                              # Run migrations
cd backend && alembic revision --autogenerate -m "description"  # New migration
```

### iOS
```bash
open ios/LangBrew.xcodeproj
xcodebuild test -scheme LangBrew -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Conventions

- API endpoints versioned under `/v1/`
- Cursor-based pagination on all list endpoints
- Standard error: `{"error": {"code": "...", "message": "...", "details": {...}}}`
- All SQLAlchemy models: UUID PKs + `created_at` / `updated_at`
- Ruff for Python linting/formatting (zero tolerance)
- Swift strict concurrency, `@Observable` view models, `async/await`
- Auth: Supabase JWT in `Authorization: Bearer` header
- CEFR levels: A1, A2, B1, B2, C1

## Agent team

| Agent | Model | Role |
| ----- | ----- | ---- |
| `coordinator` | Opus | Orchestrates multi-concern tasks, delegates to specialists |
| `architect` | Opus | Feature planning, API design, data models, architecture |
| `swift-dev` | Opus | iOS/SwiftUI code |
| `python-dev` | Opus | Python/FastAPI backend code |
| `tester` | Sonnet | Writes and runs tests, linting |
| `debugger` | Opus | Investigates and fixes bugs |
| `docs` | Sonnet | Documentation, README, ADRs, code comments |

Use `@agent-name` to invoke a specific agent, or use `coordinator` for tasks
that span multiple concerns.

## Key planning docs

- `Planning/app-description.md` — complete product spec with all screens
- `Planning/backend-plan.md` — API design, data models, architecture
- `Planning/development-roadmap.md` — milestone-by-milestone build plan
