# Requirements

Source of truth for *what* the platform must do: `PG_PLATFORM_TECHNICAL_PLAN.md` (repo root of the planning conversation) plus its two referenced artifacts:

- `prototype.html` -- the UX/visual specification. Every screen, state, and interaction it demonstrates (skeleton loading, confirm dialogs, validation, pagination, sort, recent searches) is a requirement for Flutter/Next.js to reproduce or improve on.
- The superseded Expo/Supabase app's `supabase/schema.sql` -- the domain-model specification (entities, relationships, constraints, the `book_bed()` atomic-claim logic), re-expressed as Flyway migrations owned by Spring Boot.

## Actors

- **Owner** -- runs one or more PGs. Manages PG → Floor → Room → Bed structure, students, fees, expenses, complaints, documents, reports.
- **Student** -- discovers PGs, views details, books a bed, pays rent, raises complaints, views their own records.

## Functional scope (from the technical plan §6)

| Area | Status in this repo |
|---|---|
| Auth (owner email/password, student phone/OTP, refresh, password reset) | **Built** (Phase 1) |
| Owner PG/Floor/Room/Bed management, bed auto-creation | **Built** (Phase 2) |
| Owner dashboard | **Built** (Phase 3, thin: counts + occupancy %) |
| Student management (owner-side manual add) | **Built** (Phase 4, incl. bed assign/reassign/move-out) |
| Fee management / Expense management | **Built** (Phase 5/5b, offline payment recording only -- Razorpay is Phase 12) |
| Complaint management | **Built** (Phase 6, owner-side only -- student self-service filing deferred) |
| Documents (Aadhaar/photo) | **Stubbed** (Phase 7b -- API contract + DB table built, object storage not provisioned; every upload/download call returns 501) |
| Receipts | **Built** (Phase 7a -- auto-generated per payment, snapshot-based, sequential numbering) |
| Reports (revenue, occupancy, outstanding dues) | **Built** (Phase 8, computed at read time -- see ADR-0013) |
| Student discovery (search, PG details, maps) | **Built** (Phase 9, public/unauthenticated -- Next.js web + Flutter; "maps" is a link out to Google Maps by lat/long, not an embedded map) |
| Live bed availability (SSE) | **Built** (Phase 10, PG-level granularity, single-instance in-memory broadcaster -- see ADR-0016) |
| Student registration & bed booking (concurrency-safe) | **Built** (Phase 11, Flutter-only client -- see ADR-0018; concurrency guarantee proven by `BookingConcurrencyTest`, ADR-0017) |
| Payment gateway (Razorpay) | **Stubbed** (Phase 12 -- idempotency mechanism and webhook signature verification/processing are fully built and tested; outbound order creation returns 501 until a Razorpay account is configured; see ADR-0019) |
| Notifications (push/email/WhatsApp) | **Stubbed** (Phase 13 -- fan-out/wiring to 4 real trigger points is built and tested; delivery is logged only, no FCM/email-provider credentials configured; WhatsApp explicitly deferred per the plan; see ADR-0020) |
| Real-time sync beyond bed availability | **Built** (Phase 14 -- per-user authenticated SSE stream, `/me/events/stream`, echoes all 4 of Phase 13's notification trigger points; Flutter-only client, same auth-header limitation as web `EventSource` noted in ADR-0021) |

## Non-functional requirements carried over from the plan

- No student bed can ever be double-booked -- the core trust guarantee, tested explicitly once booking exists (§8).
- Student records are never hard-deleted (soft-delete + audit trail, §7 item 5) -- implemented now via `BaseEntity`.
- An owner can only ever see/touch their own PGs' data; a student only their own private data (§7 item 6) -- implemented now via `OwnershipGuard` + per-request checks, tested in `OwnershipGuardIntegrationTest`.
- Payments must be idempotent (webhooks can be redelivered) -- **built** (Phase 12, `PaymentOrder.idempotencyKey` + idempotent webhook processing, see ADR-0019); a cross-student authorization gap in the idempotency-key-reuse path was found and fixed in the Phase 15 audit, see ADR-0022.
- OTP/auth endpoints need abuse/rate-limit protection (§7 item 7) -- implemented: `OtpService` per-phone-per-hour cap (Phase 1) plus a Phase 15 addition, per-IP rate limiting (`RateLimitFilter`) on all `/api/v1/auth/**` endpoints, since the per-phone cap alone didn't stop login brute-forcing, password-reset spam, or cycling through many phone numbers -- see ADR-0022.

## Phase 15 -- Testing & security hardening (audit pass, not new features)

Per the technical plan: "not actually a phase that happens only at the end ... treat this phase as a dedicated pass (penetration-test-style review, load test on booking concurrency, RLS-equivalent authorization audit) before pilot." Findings and fixes are recorded in full in `docs/decisions.md` ADR-0022 and `docs/security.md`; summary:
- Authorization discipline across every owner-/student-scoped service -- **audited, found consistently applied**, no changes needed beyond documenting the pattern as it actually stands (`docs/security.md`).
- Idempotency-key cross-student authorization gap in `PaymentOrderService` -- **found and fixed**, regression test added.
- Per-IP rate limiting on `/api/v1/auth/**` -- **added** (`RateLimitFilter`), closing the gap `OtpService`'s per-phone cap alone left open.
- Structured access logging for documents and payments (technical plan §8) -- **added** (`AUDIT.document`/`AUDIT.payment` loggers).
- Unhandled exceptions were previously unlogged server-side (client response was already safely generic) -- **fixed**.
- Dependency freshness (Spring Boot 3.2.5, pinned since Phase 0) -- **flagged, not resolved**: no Maven/network access in this environment to verify a version bump against a real build; left as an explicit action item for the user before Phase 16, see `docs/security.md`.
- Booking concurrency guarantee (Phase 11) -- re-confirmed still covered by `BookingConcurrencyTest`, no regression.

## Phase 16 -- Pilot deployment (prep only, no infrastructure provisioned)

Per the technical plan: "actual infra provisioning is the user's to do, but prepare everything
needed." Delivered: `docs/deployment.md` (two documented paths -- managed PaaS, or self-hosted
via `infra/docker-compose.prod.yml` + Caddy -- env var reference, migration/rollback/backup
runbook, pre-launch checklist), `application-prod.yml` (fail-fast JWT secret, trusted proxy
headers), and the self-hosted compose/Caddy files. See ADR-0023. **Not done, and not this
project's decision to make**: choosing/paying for a provider, buying a domain, actually running
a deploy, taking or testing a real backup, or running `mvn verify`/`flutter analyze` for real.
