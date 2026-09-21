# Security

## Authentication

- JWT access tokens (HMAC-SHA, 15 min default TTL), stateless -- `JwtAuthFilter` validates on every request, no server session.
- Refresh tokens are opaque random strings; only their SHA-256 hash is persisted (`refresh_tokens.token_hash`), so a DB leak alone doesn't hand out usable tokens. Each `/auth/refresh` call rotates: old token revoked, new one issued.
- Owner: email + password (BCrypt, min 8 chars). Student: phone + OTP (hashed, purpose-scoped, rate-limited -- see below), or Google sign-in. The backend verifies Google's signature, issuer, expiry, verified-email claim, and the web OAuth client ID audience before issuing its own JWT. Google identities can only create/link STUDENT users; an owner email is rejected and owner password login is unchanged.
- Password reset tokens: opaque, hashed, single-use, 30 min TTL. `requestReset` never reveals whether an email exists (no account enumeration).
- **Role and status are re-checked on every path that mints or accepts a session**, not just at password login:
  - `StudentAuthService.verifyOtp` rejects a phone whose account is not `STUDENT` (the endpoint previously issued a token carrying whatever role that phone's account held -- an owner or admin session obtainable through the student endpoint) and rejects `DISABLED` accounts. This mirrors the guards `GoogleAuthService` already applied on the other student login path.
  - `SessionService.refresh` rejects (and revokes) a refresh token whose account is `DISABLED`; otherwise disabling an account still left a live refresh token minting access tokens for its full 30-day TTL.
  - `JwtAuthFilter` treats a `DISABLED` account as unauthenticated, so disabling takes effect on the next request rather than at the end of the current access token's TTL.

  Covered by `StudentAuthGuardsTest`. **Any new token-issuing path must repeat all three checks** -- deleted, disabled, and role-appropriate.

## Authorization -- no Postgres RLS

The original Supabase prototype had row-level security for free. Spring Boot does not, unless something is built for it. **This is the single most important security pattern in the codebase**: every service method that reads or mutates an owner- or student-scoped resource takes the authenticated principal's id as an explicit parameter (from `CurrentUserProvider`/`UserPrincipal`, never a client-supplied id) and checks ownership before doing anything.

Two concrete shapes of the same discipline exist today, both audited in Phase 15 (ADR-0022) and found consistently applied:
- `OwnershipGuard.requireOwns(...)` -- used by `PgService`, `FloorService`, `RoomService`, `BedService` (the original Phase 2-3 resources).
- A private `requireOwned*`/`requireOwnedByUser` helper on the service itself, following the identical fetch-then-compare-owner-id-then-throw-`ForbiddenException` shape -- used by `StudentService.requireOwnedStudent`, `FeeService.requireOwnedFee`, `ComplaintService` (owner and student-self-service paths), `DocumentService.requireOwnedDocument` (all delegate through `requireOwnedStudent`/`requireOwnedPg` for creates/lists), `BookingService.requireOwnedByUser` (student-side), and a direct equality check in `PaymentOrderService.createOrder`.

Every one of these has a test proving cross-owner/cross-student access fails (`OwnershipGuardIntegrationTest`, and a `*IsForbidden`/`*DoesNotBelongToYou`-style test per newer service). **Any new owner- or student-scoped feature must repeat this pattern and this test, not assume JPA queries scope by owner automatically -- they don't.**

**Tenancy is data, not just a check.** Because every ownership check above resolves through `student.getPg().getOwner()`, *which PG a student row points at* is itself an access-control decision. `BookingService` used to reassign `student.pg` while creating a booking **hold** -- an unpaid, ten-minute reservation. Any student could therefore hand their own record (fees, documents, ID proof) to any PG owner on the platform, and take it away from the owner they were actually living with, by starting a booking they never paid for. The transfer now happens only when the student actually moves in (`BookingService.moveIntoPg`, called from the check-in paths); a hold and even a paid-but-future-dated booking leave the record where it is. Covered by `BookingTenantIsolationTest`. **Treat any write to `student.pg` as a privilege change, not bookkeeping.**

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

Object storage uses `S3DocumentStorageGateway` when `S3_ENABLED=true`. The bucket must remain private; authorized API calls return only time-limited signed URLs through `DocumentStorageGateway.generateSignedUrl`. Credential-free local environments select `StubDocumentStorageGateway` and fail closed with 501. Structured access logging records signed-URL access.

**Uploads are validated before they reach storage.** Both upload paths (`DocumentService.upload` and `OwnerKycService.upload`) enforce the same rules: non-empty, at most 10 MB, and a content type of `image/*` or `application/pdf`. The content type matters beyond tidiness -- it is stored on the object and is what a presigned GET later *serves the file as*, so an unvalidated `text/html` upload came back as a live page on the storage origin. `DocumentService` was missing this check while `OwnerKycService` had it; covered now by `DocumentUploadStubTest`. `spring.servlet.multipart.max-file-size` is set to match (Spring's 1 MB default otherwise rejected files at the servlet layer well below the documented limit).

## Booking concurrency (not a traditional "security" item, but a trust guarantee)

`BedRepository.findByIdForUpdate` (`SELECT ... FOR UPDATE`, Postgres pessimistic row locking) prevents two students from both being confirmed onto the same bed under concurrent requests -- the platform's core trust guarantee per the technical plan. Proven by `BookingConcurrencyTest` (two real threads, released simultaneously via a `CountDownLatch`, asserting exactly one success). See ADR-0017.

The same pattern now guards the **deposit ledger**. `DepositService.deduct`/`refund` decide against a balance summed over `deposit_transactions` rows, so two concurrent adjustments could each read the full balance and both be approved -- refunding more than was ever collected. Both paths take `BookingRepository.findByIdForUpdate` before reading the ledger, so the second caller sees a balance that already includes the first. **Any future check of the shape "sum rows, then decide, then insert a row" needs the same lock** -- the read-then-write gap is the bug, not the arithmetic.
