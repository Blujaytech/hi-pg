# Working agreements for this repo

This file is context for any Claude session (or human) working in `pg-platform/`. Read it before writing code.

## Source of truth

- `PG_PLATFORM_TECHNICAL_PLAN.md` (repo root, one level up from this file if not copied in) is the architecture brief. `docs/` is the living, more detailed version of it — when they disagree, `docs/decisions.md` explains why and wins.
- The original HTML prototype and the superseded Expo/Supabase app (referenced in the plan) are UX/domain-model references only. Do not port their code; do reproduce their screens, states, and interactions in Flutter/Next.js, and their entity/relationship shape in Flyway migrations.

## Before starting any feature

1. Check `docs/decisions.md` and open branches (`git branch -r`) — is this area already being touched?
2. Read the relevant existing module end to end before changing it.
3. Note which shared files you'll likely touch: `backend/src/main/resources/db/migration/` (check the latest `V__` number right before adding yours), `docs/api.md`, `mobile/lib/shared/api_client.dart` (or equivalent), `web/lib/api.ts`.
4. If your change touches a shared file another branch is also likely to touch, say so and sequence the two branches, or land a tiny shared-change branch first.
5. State your plan (endpoints, tables, screens) in one paragraph before writing code.

## Conventions

- **Branches**: `feature/<scope>` off `develop`. No direct commits to `main` or `develop`. See technical plan §4.
- **Migrations**: append-only, globally numbered `V{n}__description.sql` under `backend/src/main/resources/db/migration`. Never reuse or renumber a merged migration.
- **Soft delete + audit**: every domain entity extends the shared `BaseEntity` (`id`, `createdAt`, `updatedAt`, `deletedAt`, `createdBy`, `updatedBy`). Never hard-delete a row a user or business record depends on; queries must filter `deleted_at IS NULL` (repositories use the provided base query methods, not raw hard deletes).
- **Authorization**: there is no RLS (Postgres is accessed only through Spring Boot). Every service method that touches an Owner's data must explicitly verify the authenticated principal owns the resource (or its parent chain). Every such check needs a test that proves cross-owner access is rejected. See `docs/security.md`.
- **API**: versioned under `/api/v1/...`. Document new endpoints in `docs/api.md` (request/response shape) before or alongside implementation — contract-first so mobile/web can build against a stub.
- **Idempotency**: anything touching payments (Razorpay) must be safe to run twice (idempotency key + unique constraint), because webhooks can be redelivered.
- **Tests**: backend integration tests use Testcontainers against real Postgres, not H2/mocks. The bed-booking concurrency test (two simultaneous claims on one bed, exactly one succeeds) is a required, named test once booking exists — not optional QA.

## What not to do

- Don't add a second backend framework or a second database.
- Don't split into microservices — this is a single Spring Boot deployable, package-per-domain (a modular monolith). See `docs/decisions.md` ADR on this.
- Don't commit secrets. Use `.env` files (git-ignored) and `*.env.example` templates.
