# Development workflow

## Local setup

See the root `README.md` "Quick start" section. Summary: `docker compose up -d` (Postgres only) in `infra/`, then `mvn spring-boot:run` in `backend/` (runs Flyway automatically), `npm run dev` in `web/`, `flutter run` in `mobile/`.

## Environment / secrets convention

Each workspace that needs config has a `.env.example` (or `application-dev.yml` for the backend) checked in; real values go in a git-ignored `.env` / local override. Never commit a real secret. See `security.md`.

- `infra/.env.example` -- JWT secret, CORS origin, and placeholders for Razorpay/Maps/Google OAuth/S3 credentials that later phases will need.
- `web/.env.example` -- `NEXT_PUBLIC_API_BASE_URL`.
- `mobile/` -- no `.env` file; uses `--dart-define=API_BASE_URL=...` at build/run time (see `mobile/lib/core/env.dart`). Document any new `--dart-define` key here when one is added.

## Branching, PRs, migrations

See root `PG_PLATFORM_TECHNICAL_PLAN.md` §4-5 and `CLAUDE.md` -- `feature/<scope>` off `develop`, no direct commits to `develop`/`main`, migrations are append-only and globally numbered (check the latest `V__` right before adding yours).

## CI

`.github/workflows/ci.yml` runs path-filtered jobs (backend/web/mobile only run when their folder changed). Backend job runs `mvn verify`, which includes the Testcontainers integration tests -- GitHub-hosted runners have Docker available for this. Add a required-status-check branch protection rule on `develop` and `main` once the repo is pushed to GitHub (not doable from this local scaffold).

## Testing expectations

- Backend: integration tests against real Postgres via Testcontainers (`AbstractIntegrationTest`), not H2/mocks. Every ownership check needs a cross-owner-denied test (see `OwnershipGuardIntegrationTest`). The bed-booking concurrency test (Phase 11) is a required, named test, not manual QA.
- Flutter: widget tests mirroring `lib/` structure under `test/`.
- Web: `next lint` + `next build` in CI for now; add real tests (Playwright/RTL) once there's meaningful client logic to test.

## Staging environment

Not yet provisioned -- needed before pilot deployment so Razorpay/Maps/notification integrations can be tested against real-but-non-production credentials (technical plan §8).
