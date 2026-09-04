# Security

## Authentication

- JWT access tokens (HMAC-SHA, 15 min default TTL), stateless -- `JwtAuthFilter` validates on every request, no server session.
- Refresh tokens are opaque random strings; only their SHA-256 hash is persisted (`refresh_tokens.token_hash`), so a DB leak alone doesn't hand out usable tokens. Each `/auth/refresh` call rotates: old token revoked, new one issued.
- Owner: email + password (BCrypt, min 8 chars). Student: phone + OTP (hashed, purpose-scoped, rate-limited -- see below). Google OAuth is a named stub (`GoogleAuthService`) -- not implemented, returns 501.
- Password reset tokens: opaque, hashed, single-use, 30 min TTL. `requestReset` never reveals whether an email exists (no account enumeration).

## Authorization -- no Postgres RLS

The original Supabase prototype had row-level security for free. Spring Boot does not, unless something is built for it. **This is the single most important security pattern in the codebase**: every service method that reads or mutates an owner- or student-scoped resource takes the authenticated principal's id as an explicit parameter (from `CurrentUserProvider`/`UserPrincipal`, never a client-supplied id) and checks ownership before doing anything.

Two concrete shapes of the same discipline exist today, both audited in Phase 15 (ADR-0022) and found consistently applied:
- `OwnershipGuard.requireOwns(...)` -- used by `PgService`, `FloorService`, `RoomService`, `BedService` (the original Phase 2-3 resources).
- A private `requireOwned*`/`requireOwnedByUser` helper on the service itself, following the identical fetch-then-compare-owner-id-then-throw-`ForbiddenException` shape -- used by `StudentService.requireOwnedStudent`, `FeeService.requireOwnedFee`, `ComplaintService.requireOwnedComplaint`, `DocumentService.requireOwnedDocument` (all delegate through `requireOwnedStudent`/`requireOwnedPg` for creates/lists), `BookingService.requireOwnedByUser` (student-side), and a direct equality check in `PaymentOrderService.createOrder`.

Every one of these has a test proving cross-owner/cross-student access fails (`OwnershipGuardIntegrationTest`, and a `*IsForbidden`/`*DoesNotBelongToYou`-style test per newer service). **Any new owner- or student-scoped feature must repeat this pattern and this test, not assume JPA queries scope by owner automatically -- they don't.**

**Phase 15 finding, fixed**: `PaymentOrderService.createOrder`'s idempotency-key-reuse path returned an existing `PaymentOrder` without re-checking it belonged to the calling student (the DB-level `idempotency_key` uniqueness is global, not per-student) -- see ADR-0022 item 2. Fixed; covered by a regression test.

## Rate limiting / abuse prevention (technical plan §7 item 7)

Two layers, both audited/added in Phase 15 (ADR-0022):

1. **Per-phone, per-purpose** (`OtpService.requestOtp`, since Phase 1): caps OTP requests to `app.otp.max-attempts-per-hour` (default 5), plus a 5-minute code expiry and a 5-attempt verify limit. SMS is a cost-per-send abuse target -- do not relax this without a replacement control (e.g. CAPTCHA) in front of it.
2. **Per-IP, per-path, per-window** (`RateLimitFilter`, Phase 15): caps requests to any `/api/v1/auth/**` endpoint to `app.rate-limit.auth.max-requests` (default 20) per `app.rate-limit.auth.window-seconds` (default 60) from a single client IP, returning 429 over the limit. Closes the gap where layer 1 alone didn't stop login brute-forcing or password-reset spam, and didn't stop an attacker from cycling through *many* phone numbers to defeat the per-phone OTP cap.
   - **In-memory, single-instance only** -- same caveat as the SSE broadcasters (ADR-0016, ADR-0021): a multi-instance deployment gets roughly `instanceCount x limit` through before every instance independently trips. Revisit with a shared store (Redis, or a Postgres table) before scaling horizontally.
   - **Trusts `X-Forwarded-For`** for the client IP -- only safe behind a reverse proxy/load balancer that sets this header itself and never forwards a client-supplied value unchanged. **Confirm this before Phase 16 goes live**; deployed with nothing in front of it, the limiter is trivially bypassable (a different `X-Forwarded-For` per request = a fresh bucket every time).

## Structured access logging (technical plan §8)

`AUDIT.document` and `AUDIT.payment` SLF4J loggers (named separately from ordinary application logs so they can be routed/retained differently without new infrastructure) emit one line per document `downloadUrl`/`delete` call and per successful Razorpay webhook capture -- who, what, when. Added in Phase 15 (ADR-0022 item 4). This is a first step (a searchable log line), not a queryable audit-trail table -- revisit if compliance ever needs query-by-student or a retention guarantee independent of log retention.

Unhandled exceptions are logged server-side at ERROR (`GlobalExceptionHandler`, Phase 15) without changing what the client sees -- see "Error responses never leak internals" below.

## Idempotent payments

`PaymentOrder.idempotencyKey` is client-generated per payment attempt and unique at the DB level (`uq_payment_orders_idempotency_key`, global across all students -- see the authorization note above for the gap this created and its fix). `PaymentOrderService.createOrder` checks for an existing order with that key before calling the gateway at all, so a client retry after a dropped response never double-charges or duplicates an order. The Razorpay webhook handler (`handleWebhookPayload`) checks `PaymentOrder.status == PAID` before processing anything, making it safe against Razorpay's documented webhook redelivery. See ADR-0019.

## Error responses never leak internals

`GlobalExceptionHandler`'s catch-all (`Exception.class`) always returns a fixed `"Something went wrong"` message -- never `ex.getMessage()` or a stack trace -- to avoid exposing internals (e.g. a raw SQL exception revealing schema/table names). Specific, safe-to-expose messages are only ever returned by handlers for expected exception types (`NotFoundException`, `ForbiddenException`, `ConflictException`, validation errors) whose messages are authored by this codebase, not by an underlying library or the database driver.

## Secrets

Never commit real secrets. `.env.example` files document the shape; real values live in `.env` (git-ignored) locally, and in a proper secrets manager beyond local dev. `app.jwt.secret` in `application.yml` has a dev-only fallback value that **must** be overridden via `JWT_SECRET` outside local dev. Same pattern for `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET`/`RAZORPAY_WEBHOOK_SECRET` -- blank by default, only ever read from environment variables.

## CORS

`SecurityConfig.corsConfigurationSource` reads allowed origins from `app.cors.allowed-origins` (env-configurable, comma-separated) -- never a wildcard, and `allowCredentials(true)` requires an explicit origin list rather than `*` anyway (browsers reject the combination). Confirm the production value is the real web app origin(s) only before Phase 16.

## Dependency freshness -- open item, not resolved this pass

`backend/pom.xml` pins `spring-boot-starter-parent` at 3.2.5 (released April 2024). No version bump was made during the Phase 15 audit: there is no Maven/network access in the environment these phases were built in to verify a bump doesn't break the build, and an unverified dependency bump is worse than an old-but-known-working one. **Action item before Phase 16**: run `mvn versions:display-dependency-updates`, check Spring's published security advisories for the 3.2.x line, and upgrade with a real `mvn verify` run backing up the change.

## Documents (Aadhaar/photos)

Object storage (S3-compatible) with signed-URL access is designed for (`DocumentStorageGateway.generateSignedUrl`), never a public bucket -- but the only implementation today (`StubDocumentStorageGateway`) throws `UnsupportedOperationException`, so no document can actually be stored yet (Phase 7b, ADR-0011/ADR-0012-equivalent). Structured access logging (above) is in place for when it is.

## Booking concurrency (not a traditional "security" item, but a trust guarantee)

`BedRepository.findByIdForUpdate` (`SELECT ... FOR UPDATE`, Postgres pessimistic row locking) prevents two students from both being confirmed onto the same bed under concurrent requests -- the platform's core trust guarantee per the technical plan. Proven by `BookingConcurrencyTest` (two real threads, released simultaneously via a `CountDownLatch`, asserting exactly one success). See ADR-0017.
