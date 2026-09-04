# PG Management & Discovery Platform

A platform for PG (paying-guest accommodation) owners to manage their properties (PGs → Floors → Rooms → Beds), students, fees, expenses, complaints, and documents, and for students to discover, view, and book PG beds with live availability and online payments.

## Repo layout.

```
pg-platform/
├── mobile/     Flutter app (Owner + Student flows, one codebase)
├── web/        Next.js (public discovery + owner web console)
├── backend/    Spring Boot REST API (single deployable, modular monolith)
├── database/   ER diagrams, kept in sync with backend/src/main/resources/db/migration
├── infra/      docker-compose for local dev, deployment configs
└── docs/       requirements, architecture, database, api, security, workflow, decisions
```

## Status

Implemented so far (see `docs/decisions.md` for the running log):

- **Phase 0** — monorepo scaffold, Spring Boot skeleton + health check, Flutter skeleton + login shell, Next.js skeleton + landing page, docker-compose Postgres.
- **Phase 1** — Auth: JWT issuance/refresh, Owner email+password signup/login, Student phone+OTP signup/login, password reset (owner), role-based access.
- **Phase 2** — Owner core: PG → Floor → Room → Bed management, with automatic bed creation from a room's sharing count.
- **Phase 3** — Owner dashboard: PG/floor/room/bed counts, occupancy %, active student count (per-owner and per-PG).
- **Phase 4** — Student management: owner adds/edits students, assigns/reassigns/frees beds, marks a student moved out.
- **Phase 5 / 5b** — Fee management (per-student monthly charges, offline payment recording, auto status PENDING → PARTIALLY_PAID → PAID) and Expense management (per-PG costs by category). Dashboard now also shows pending dues, this-month collections/expenses/net.
- **Phase 6** — Complaint management: owner logs a complaint on a student's behalf, tracks it through OPEN → IN_PROGRESS → RESOLVED/CLOSED (resolution notes required to resolve). Student *self-service* filing is deferred -- see `docs/decisions.md`.

- **Phase 7** — Receipts: auto-generated (one per payment, never a direct `POST`), snapshot-based so past receipts never change if the student/PG record is edited later, sequentially numbered from a DB sequence (`RCPT-<year>-<seq>`). Document storage (Aadhaar/photo uploads): full API contract + DB table built, but every upload/download call returns `501` until a real object-storage bucket is provisioned -- see `docs/decisions.md` (ADR-0012) for what's needed to finish it.

- **Phase 8** — Reports: revenue (monthly collected/expenses/net), occupancy (per PG and owner-wide), and outstanding dues, computed live from existing Fee/Payment/Expense/Bed data -- no reporting tables or scheduled jobs (see `docs/decisions.md` ADR-0013).

- **Phase 9** — Student discovery: public, unauthenticated PG search (`/public/pgs`) and details (`/public/pgs/{pgId}`) with live per-room bed availability. This is also where the **Next.js web app came online** (`/search`, `/pgs/{pgId}`, server components) alongside a matching Flutter search/details screen -- both read the same backend endpoints. "Maps" is a link out to Google Maps by lat/long, not an embedded map view. No booking action yet -- see `docs/decisions.md` ADR-0015.

- **Phase 10** — Live bed availability over Server-Sent Events: every owner action that changes a bed's status pushes a `{pgId, totalBeds, availableBeds}` snapshot to anyone watching that PG's details page, on both the web app (`LiveAvailabilityBadge`) and Flutter (`PgDetailsScreen`). PG-level only, single backend instance -- see `docs/decisions.md` ADR-0016 for the tradeoffs and what to revisit if the backend is ever scaled horizontally.

- **Phase 11** — Student registration & bed booking, the project's critical-path business rule: two students can never end up confirmed on the same bed, even under concurrent requests. Enforced with a Postgres row lock (not a client-side check), proven by an explicit two-simultaneous-requests test (`BookingConcurrencyTest`) -- see `docs/decisions.md` ADR-0017. A booking also creates/links the logged-in student's own Student record for the first time (`students.user_id`, ADR-0018). Ships in the Flutter app only for now -- the web app has no student sign-in yet.

- **Phase 12** — Razorpay payments: a Student can now view their own fees (`My Fees`, Flutter) and the backend has a full idempotent payment-order + webhook pipeline (client-generated idempotency keys, HMAC-SHA256 webhook signature verification, safe-to-redeliver processing) -- but outbound order creation returns `501` until a real Razorpay account is configured, so there's no "Pay Online" button anywhere yet. See `docs/decisions.md` ADR-0019 for what's stubbed vs. fully real, and what credentials unlock the rest.

- **Phase 13** — Notifications: a `NotificationService` fans out to push (every registered device token) and email whenever a booking is confirmed/cancelled, an online payment is received, or a complaint is resolved -- wired into real trigger points, not just a capability sitting unused. Delivery is logged only (`LoggingNotificationGateway`) since no Firebase/email-provider account is configured, and no Flutter client registers a real push token yet -- see `docs/decisions.md` ADR-0020 for exactly what's needed to make it real.
- **Phase 14** — Broader real-time sync: a per-user authenticated SSE stream (`GET /me/events/stream`, `UserEventBroadcaster`) generalizes Phase 10's public bed-availability pattern to every `NotificationService` trigger point -- booking confirmed/cancelled, payment received, complaint resolved all get a live in-app echo, with zero changes needed in `BookingService`/`PaymentOrderService`/`ComplaintService`. Flutter-only client (`LiveEventsListener`, wraps the student home screen and the owner PG list screen) since browser `EventSource` can't set an `Authorization` header -- see `docs/decisions.md` ADR-0021.
- **Phase 15** — Testing & security hardening: a dedicated audit pass (not new features) against the technical plan's own risk list -- confirmed owner/student authorization discipline is applied consistently everywhere, found and fixed a cross-student authorization gap in Razorpay idempotency-key reuse, added per-IP rate limiting on all `/auth/**` endpoints (`RateLimitFilter`, on top of the existing per-phone OTP cap), added structured access logging for documents/payments, and fixed unhandled exceptions going unlogged server-side. Dependency freshness (Spring Boot 3.2.5) flagged as an open action item rather than bumped blind -- see `docs/decisions.md` ADR-0022 and `docs/security.md`.
- **Phase 16** — Pilot deployment: preparation only, per the plan ("actual infra provisioning is the user's to do"). `docs/deployment.md` documents two paths -- a managed PaaS (Railway/Render/Fly + a managed Postgres + Vercel), or self-hosted (`infra/docker-compose.prod.yml` + Caddy for automatic HTTPS and correct `X-Forwarded-For`) -- plus an environment variable reference, a migration/rollback/backup runbook, and a pre-launch checklist. `application-prod.yml` fails fast on a missing `JWT_SECRET` instead of falling back to the dev secret. No account, domain, or server has actually been provisioned -- see ADR-0023.

All 16 phases from the technical plan's §6 are now addressed to the extent buildable without the user's own infrastructure decisions and credentials. What's left is exactly what `docs/deployment.md`'s pre-launch checklist says: provision real infrastructure, run a real `mvn verify`/`flutter analyze`, and replace the three still-stubbed integrations (Documents/S3, Razorpay, push notifications/Firebase) with real credentials once each is provisioned — no code changes needed beyond swapping each stub implementation, per its own ADR.

## Quick start (local dev)

Prerequisites: JDK 17+, Maven 3.9+, Node 20+, Flutter 3.x, Docker Desktop.

```bash
# 1. Start Postgres
cd infra && docker compose up -d

# 2. Backend (runs Flyway migrations automatically on boot)
cd ../backend && mvn spring-boot:run
# -> http://localhost:8080/api/v1/health

# 3. Web
cd ../web && npm install && npm run dev
# -> http://localhost:3000

# 4. Mobile
cd ../mobile && flutter pub get && flutter run
```

Copy `infra/.env.example` to `infra/.env` and `backend/src/main/resources/application-dev.yml` values as needed before running against real credentials (Razorpay, Google OAuth, SMS/OTP provider, S3-compatible storage).

## Documentation

Start with `docs/architecture.md`, then `docs/database.md` and `docs/api.md`. Every non-trivial decision is logged, dated, in `docs/decisions.md` — read it before assuming *why* something is built a certain way.

## Working agreements

See `CLAUDE.md` for repo conventions AI-assisted contributors (and humans) should follow.
