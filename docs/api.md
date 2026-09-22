# API

Base path: `/api/v1`. JSON in, JSON out. Errors follow one shape (`com.pgplatform.common.ApiError`):

```json
{
  "timestamp": "2026-01-01T00:00:00Z",
  "status": 400,
  "error": "VALIDATION_ERROR",
  "message": "Request validation failed",
  "path": "/api/v1/auth/owner/signup",
  "details": ["email: must be a well-formed email address"]
}
```

Auth: `Authorization: Bearer <accessToken>` on every endpoint except `/auth/**`, `/health`, `/public/**`.

## Auth (`/auth`) -- all public

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/auth/owner/signup` | `{fullName, email, password, phone?}` | 201, returns `AuthResponse` |
| POST | `/auth/owner/login` | `{email, password}` | returns `AuthResponse` |
| POST | `/auth/student/otp/request` | `{phone}` | 202, sends OTP (logged, not really sent -- see `NotificationGateway`) |
| POST | `/auth/student/otp/verify` | `{phone, code, fullName?}` | returns `AuthResponse`; creates the student on first verify |
| POST | `/auth/student/google` | `{idToken}` | verifies a Google ID token and returns `AuthResponse`; creates or signs in a STUDENT only |
| POST | `/auth/refresh` | `{refreshToken}` | rotates refresh token, returns new `AuthResponse` |
| POST | `/auth/logout` | `{refreshToken}` | 204, revokes that refresh token |
| POST | `/auth/owner/password-reset/request` | `{email}` | 200, always the same message (no account enumeration) |
| POST | `/auth/owner/password-reset/confirm` | `{token, newPassword}` | 204 |

`AuthResponse`: `{accessToken, refreshToken, userId, fullName, role}`.

All `/auth/**` endpoints are also rate-limited per client IP (Phase 15 -- `RateLimitFilter`, default 20 requests/60s per path): exceeding it returns 429 with `error: TOO_MANY_REQUESTS`. See `docs/security.md`.

## Owner: PG (`/owner/pgs`) -- requires role OWNER

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/pgs` | create |
| GET | `/owner/pgs` | list mine |
| GET | `/owner/pgs/{pgId}` | 403 if not mine |
| PUT | `/owner/pgs/{pgId}` | full update incl. `status` |
| DELETE | `/owner/pgs/{pgId}` | soft delete |

`PgCreateRequest`: `{name, address, city, state?, pincode?, latitude?, longitude?, description?, genderPreference: MALE|FEMALE|CO_ED}`.
`PgUpdateRequest`: same + `status: ACTIVE|INACTIVE`.

## Owner: Floor (`/owner/pgs/{pgId}/floors`, `/owner/floors/{floorId}`)

POST/GET on the first path, PUT/DELETE on the second. Body: `{name, floorNumber}`.

## Owner: Room (`/owner/floors/{floorId}/rooms`, `/owner/rooms/{roomId}`)

POST/GET on the first path, PUT/DELETE on the second.
Body: `{roomNumber, sharingCount, rentPerBed, roomType: NON_AC|AC}`.
**Creating a room auto-creates `sharingCount` beds.** Updating `sharingCount` grows/shrinks the bed set (409 if shrinking below the number of occupied beds). Response includes the current `beds[]`.

## Owner: Bed (`/owner/rooms/{roomId}/beds`, `/owner/beds/{bedId}/status`)

GET list; `PATCH /owner/beds/{bedId}/status` with `{status: AVAILABLE|OCCUPIED|MAINTENANCE}`.

## Owner: Dashboard (`/owner/dashboard`, `/owner/pgs/{pgId}/dashboard`) -- requires role OWNER

Both GET, no body. Response (`DashboardSummaryResponse`):

```json
{
  "totalPgs": 2,
  "totalFloors": 5,
  "totalRooms": 20,
  "totalBeds": 48,
  "occupiedBeds": 31,
  "availableBeds": 15,
  "maintenanceBeds": 2,
  "occupancyPercentage": 64.58,
  "totalActiveStudents": 31
}
```

`/owner/dashboard` aggregates across all of the caller's PGs; `/owner/pgs/{pgId}/dashboard` scopes to one (403 if not the caller's). Deliberately thin -- no fee/expense data yet (Phase 3 note in the technical plan).

## Owner: Student (`/owner/pgs/{pgId}/students`, `/owner/students/{studentId}`)

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/pgs/{pgId}/students` | create; optional `bedId` assigns immediately |
| GET | `/owner/pgs/{pgId}/students` | list all students (active + moved out) for a PG |
| GET | `/owner/students/{studentId}` | 403 if not caller's |
| PUT | `/owner/students/{studentId}` | update profile fields (not bed/status) |
| POST | `/owner/students/{studentId}/assign-bed` | `{bedId}` -- assigns/reassigns; frees the previous bed if any; 409 if the target bed isn't `AVAILABLE`; 403 if the bed belongs to a different PG |
| POST | `/owner/students/{studentId}/move-out` | no body; frees the bed, sets `status=MOVED_OUT`, `moveOutDate=today` |
| DELETE | `/owner/students/{studentId}` | soft delete; frees the bed first if still assigned |

`StudentCreateRequest`: `{fullName, phone, email?, guardianName?, guardianPhone?, permanentAddress?, idProofNumber?, dateOfJoining, bedId?}`.
`StudentResponse` adds `bedId`, `bedLabel` (null if unassigned), `status: ACTIVE|MOVED_OUT`, `moveOutDate`.

**Note**: `idProofNumber` (Aadhaar etc.) is stored as plain text today -- there is no document/encryption-at-rest layer yet (Phase 7). See `docs/security.md`.

## Owner: Fees & Payments (`/owner/students/{studentId}/fees`, `/owner/pgs/{pgId}/fees`, `/owner/fees/{feeId}`, `/owner/fees/{feeId}/payments`)

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/students/{studentId}/fees` | create one billing period's charge; 409 if a fee already exists for that student+month+year |
| GET | `/owner/students/{studentId}/fees` | list a student's fees, newest period first |
| GET | `/owner/pgs/{pgId}/fees` | list every fee across a PG (all students) |
| GET | `/owner/fees/{feeId}` | one fee incl. its payments |
| POST | `/owner/fees/{feeId}/payments` | record an offline payment against a fee; recomputes the fee's status |
| DELETE | `/owner/fees/{feeId}` | soft delete |

`FeeCreateRequest`: `{periodMonth (1-12), periodYear, amount, dueDate, notes?}`.
`PaymentCreateRequest`: `{amountPaid, paidOn, method: CASH|UPI|BANK_TRANSFER|CARD|OTHER, reference?, note?}` -- offline recording only; Razorpay (online, webhook-driven) is Phase 12.
`FeeResponse` adds computed fields: `amountPaid`, `balance` (amount − amountPaid), `status: PENDING|PARTIALLY_PAID|PAID` (stored, updated on each payment), and **`overdue`** -- a value computed at read time from `dueDate < today && status != PAID`, never stored, so nothing needs a scheduled job to keep it correct.

## Owner: Expenses (`/owner/pgs/{pgId}/expenses`, `/owner/expenses/{expenseId}`)

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/pgs/{pgId}/expenses` | create |
| GET | `/owner/pgs/{pgId}/expenses` | list, newest first |
| PUT | `/owner/expenses/{expenseId}` | full update |
| DELETE | `/owner/expenses/{expenseId}` | soft delete |

`ExpenseCreateRequest`/response: `{category: MAINTENANCE|UTILITIES|SALARY|SUPPLIES|OTHER, description, amount, expenseDate}`.

## Owner: Dashboard -- now richer

`DashboardSummaryResponse` (both `/owner/dashboard` and `/owner/pgs/{pgId}/dashboard`) gained four fields once Fees/Expenses existed: `totalPendingDues` (sum of unpaid/partial fee amounts), `collectedThisMonth` (payments recorded this calendar month), `expensesThisMonth`, `netThisMonth` (collected − expenses). Still read-only aggregation, still no fee/expense writes happen from the dashboard endpoints themselves.

## Owner: Complaints (`/owner/students/{studentId}/complaints`, `/owner/pgs/{pgId}/complaints`, `/owner/complaints/{complaintId}`)

Owners may log a complaint on a student's behalf. Linked student accounts also have a self-service API below.

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/students/{studentId}/complaints` | create, status starts `OPEN` |
| GET | `/owner/students/{studentId}/complaints` | list for one student |
| GET | `/owner/pgs/{pgId}/complaints` | list every complaint across a PG |
| GET | `/owner/complaints/{complaintId}` | one complaint |
| PATCH | `/owner/complaints/{complaintId}/status` | `{status, resolutionNotes?}` -- 409 if setting `RESOLVED` without `resolutionNotes` |
| DELETE | `/owner/complaints/{complaintId}` | soft delete |

`ComplaintCreateRequest`: `{category: MAINTENANCE|CLEANLINESS|NOISE|SECURITY|BILLING|OTHER, priority?: LOW|MEDIUM|HIGH (default MEDIUM), description}`.
`ComplaintResponse` includes `pgId`, `pgName`, `status: OPEN|IN_PROGRESS|RESOLVED|CLOSED`, and `resolvedAt` -- set automatically (to now / cleared to null) whenever status moves into or out of `RESOLVED`/`CLOSED`, never set directly by the client.

## Student: Complaints (`/student/complaints`)

Authenticated, `hasRole('STUDENT')`. The student identity is resolved from the JWT's user id and its linked Student record; no student id is accepted from the client. An account that has not booked a bed yet gets the same actionable 404 used by self-service fees.

| Method | Path | Notes |
|---|---|---|
| POST | `/student/complaints` | `ComplaintCreateRequest`; files against the caller's linked Student record, starts `OPEN`, and emits a live notification to the PG owner |
| GET | `/student/complaints` | list the caller's complaints, newest first |
| GET | `/student/complaints/{complaintId}` | one complaint; 403 if it belongs to another student |

Students cannot change complaint status or delete complaints. The owner remains responsible for moving a complaint through `OPEN -> IN_PROGRESS -> RESOLVED/CLOSED` and supplying resolution notes.

## Owner: Dashboard -- now includes complaints

`DashboardSummaryResponse` gained `openComplaints` (count of `OPEN` + `IN_PROGRESS` complaints), alongside the fee/expense fields from Phase 5.

## Owner: Receipts (`/owner/students/{studentId}/receipts`, `/owner/pgs/{pgId}/receipts`, `/owner/receipts/{receiptId}`)

Read-only from the API's point of view -- there is no `POST` here. A `Receipt` is generated automatically, server-side, every time `FeeService.recordPayment` saves a `Payment`; one receipt per payment, never per fee.

| Method | Path | Notes |
|---|---|---|
| GET | `/owner/students/{studentId}/receipts` | list for one student, newest first |
| GET | `/owner/pgs/{pgId}/receipts` | list every receipt across a PG |
| GET | `/owner/receipts/{receiptId}` | one receipt |

`ReceiptResponse`: `{receiptNumber, studentNameSnapshot, pgNameSnapshot, feePeriodMonth, feePeriodYear, amount, paidOn, method}`. `receiptNumber` is formatted `RCPT-<year>-<6-digit sequence>`, drawn from a dedicated Postgres sequence (`receipt_number_seq`) so numbers are gapless-enough and never reused, even across PGs/owners. The name/PG/period fields are **snapshotted at issue time** rather than joined live, so a receipt keeps reading correctly even if the student is later renamed or moved out -- see `docs/decisions.md`.

## Owner: Documents (`/owner/students/{studentId}/documents`, `/owner/documents/{documentId}/...`)

**Stubbed pending object storage credentials** -- every write/read of file bytes returns `501 Not Implemented`. The endpoint contracts exist now so clients can be built against them; see `docs/decisions.md` for the deferred-credentials decision (same pattern as Google OAuth in Phase 1).

| Method | Path | Notes |
|---|---|---|
| POST | `/owner/students/{studentId}/documents` (multipart) | fields: `documentType: ID_PROOF\|PHOTO\|OTHER`, `file` -- **always 501** today |
| GET | `/owner/students/{studentId}/documents` | list metadata (empty today -- uploads always fail before a row is saved) |
| GET | `/owner/documents/{documentId}/download-url` | `{url}` -- **always 501** today |
| DELETE | `/owner/documents/{documentId}` | soft delete metadata row; safe to call even though no file was ever stored |

`DocumentService.upload` calls the storage gateway **before** saving any `Document` row, so a 501 here never leaves an orphan metadata record with no backing file.

## Owner: Reports (`/owner/reports/...`, `/owner/pgs/{pgId}/reports/...`)

Every report is computed at request time from Fee/Payment/Expense/Bed rows -- nothing is pre-aggregated or cached. Both an owner-wide (across every PG) and a per-PG variant exist for each report; the Flutter app uses only the owner-wide ones today.

| Method | Path | Notes |
|---|---|---|
| GET | `/owner/reports/revenue?months=6` | `List<MonthlyFinancialSummary>`, oldest month first, `months` clamped to 1-24 |
| GET | `/owner/pgs/{pgId}/reports/revenue?months=6` | same, scoped to one PG |
| GET | `/owner/reports/occupancy` | `List<OccupancyReportResponse>`, one entry per PG the owner has |
| GET | `/owner/pgs/{pgId}/reports/occupancy` | single `OccupancyReportResponse` |
| GET | `/owner/reports/outstanding-dues` | `List<OutstandingDueResponse>`, every non-PAID fee across all PGs, oldest due date first |
| GET | `/owner/pgs/{pgId}/reports/outstanding-dues` | same, scoped to one PG |

`MonthlyFinancialSummary`: `{year, month, collected, expenses, net}` -- `collected` sums `Payment.amountPaid` in that month, `expenses` sums `Expense.amount`, `net = collected - expenses`.
`OccupancyReportResponse`: `{pgId, pgName, totalBeds, occupiedBeds, availableBeds, maintenanceBeds, occupancyPercentage}`.
`OutstandingDueResponse`: `{feeId, studentId, studentName, pgId, pgName, periodMonth, periodYear, amount, amountPaid, balance, dueDate, overdue}`.

## Public: Discovery (`/public/pgs`, `/public/pgs/{pgId}`) -- unauthenticated

Technical plan §6 Phase 9. Listed under `SecurityConfig`'s `/api/v1/public/**` permitAll -- no `Authorization` header needed or expected. Only `ACTIVE` PGs are ever returned, and nothing owner-only (owner identity, students, financials) is exposed.

| Method | Path | Notes |
|---|---|---|
| GET | `/public/pgs?q=&city=&genderPreference=&minRent=&maxRent=&page=0&size=20` | paginated search, all filters optional; `size` clamped to 50. `q` is free text matched word by word (case-insensitive, partial) against name, address, city, state and pincode -- every word must match, first 3 words used, `%`/`_` are literal. `city` is an exact (case-insensitive) city match, kept for existing clients |
| GET | `/public/pgs/{pgId}` | full details incl. per-room live availability; 404 if not found or not `ACTIVE` |

Search response is `PagedResponse<PgSearchResultResponse>` -- a project-wide pagination envelope (`{content, page, size, totalElements, totalPages}`, see `docs/decisions.md`), not Spring's raw `Page`. `PgSearchResultResponse`: `{id, name, city, address, description, genderPreference, latitude, longitude, availableBeds, minRentPerBed, maxRentPerBed}` -- rent range is derived from that PG's `Room.rentPerBed` values, not a stored field on the PG itself.

`PgDetailsResponse`: `{id, name, address, city, state, pincode, description, genderPreference, latitude, longitude, totalBeds, availableBeds, floors: [{floorId, name, floorNumber, rooms: [{roomId, roomNumber, roomType, sharingCount, rentPerBed, availableBeds}]}]}`. No photos yet -- Document storage (Phase 7b) is still stubbed, so there's nothing real to attach.

Booking and strict date-range availability are now implemented; see the current-contract section below.

## Public: Live bed availability (`/public/pgs/{pgId}/availability/stream`) -- Phase 10

Server-Sent Events, unauthenticated, same permitAll rule as the rest of `/public/**`. Sends one named `availability` event immediately on connect (the current snapshot) and again every time an owner action changes that PG's bed availability (assign/reassign/move-out, manual bed status change, room sharing-count change, room delete). A `:keep-alive` comment is sent every 25s to hold the connection through proxies that close idle HTTP connections.

Event payload (`BedAvailabilityEvent`): `{pgId, totalBeds, availableBeds}` -- PG-level only, not broken down per room. Both the Next.js details page (`LiveAvailabilityBadge`, a client component) and the Flutter `PgDetailsScreen` subscribe to this; per-room numbers on both still come from the one-time `/public/pgs/{pgId}` fetch and only refresh on reload/pull-to-refresh -- see `docs/decisions.md` ADR-0016 for why the scope stops there.

## Student: Bookings (`/student/bookings`, `/student/bookings/{bookingId}`) -- Phase 11

Authenticated, `hasRole('STUDENT')`. This is the first endpoint that links a Student *login* to a Student *record* -- see `docs/decisions.md` ADR-0017/ADR-0018 and `Student.user` (added in V9).

| Method | Path | Notes |
|---|---|---|
| POST | `/student/bookings` | `{bedId, moveInDate}` -- instant-confirm, no owner approval step; 409 if the bed is no longer available or the student already has an active booking |
| GET | `/student/bookings` | every booking (any status) for the logged-in student, newest first |
| GET | `/student/bookings/{bookingId}` | one booking; 403 if it isn't yours |
| POST | `/student/bookings/{bookingId}/cancel?reason=` | frees the bed, marks the linked Student `MOVED_OUT`; 409 if already cancelled |

`BookingResponse`: `{id, studentId, pgId, pgName, bedId, bedLabel, roomNumber, status: CONFIRMED\|CANCELLED, moveInDate, confirmedAt, cancelledAt, cancellationReason}`.

**The guarantee this phase exists for**: at most one `CONFIRMED` booking can ever exist for a given bed. Enforced with a Postgres row lock (`SELECT ... FOR UPDATE` via `BedRepository.findByIdForUpdate`) taken before the availability check inside `BookingService.book`, backed by a partial unique index (`uq_bookings_bed_confirmed`) as defense-in-depth. `BookingConcurrencyTest` is the explicit two-simultaneous-requests acceptance test the technical plan calls for -- see `docs/decisions.md` ADR-0017.

Booking a specific bed is Flutter-only for now (`PgSearchScreen` → `PgDetailsScreen` → tap a bed chip → `MyBookingsScreen`) -- the web app has no student sign-in yet, see ADR-0018. The public discovery response (`/public/pgs/{pgId}`, Phase 9) now also includes each room's `availableBedOptions: [{id, label}]` so a client can pick a specific bed to book.

## Student: Self-service fees (`/student/fees`) -- Phase 12

Authenticated, `hasRole('STUDENT')`. First read-only view a student has of their own billing -- requires a linked Student record (see ADR-0018); a student who has never booked gets a clean 404 ("book a bed first"), not an empty list mistaken for "nothing owed."

| Method | Path | Notes |
|---|---|---|
| GET | `/student/fees` | every fee for the logged-in student, newest period first |
| GET | `/student/fees/{feeId}` | one fee; 403 if it isn't yours |

Same `FeeResponse` shape as the owner endpoints (`docs/api.md`'s Fees section) -- only the authorization path differs (by student identity, not PG ownership).

## Student: Online payment orders (`/student/fees/{feeId}/payment-orders`) -- original Phase 12 contract

| Method | Path | Notes |
|---|---|---|
| POST | `/student/fees/{feeId}/payment-orders` | `{idempotencyKey}` -- creates a Razorpay order when credentials and PG onboarding are configured; otherwise 501/409 respectively |

`PaymentOrderResponse`: `{id, feeId, amount, currency, status: CREATED\|PAID\|FAILED, razorpayOrderId}`. `idempotencyKey` is client-generated (one per payment attempt, e.g. a UUID) -- retrying the same attempt with the same key returns the existing order instead of creating a duplicate or calling Razorpay twice; this part works today and is tested today, independent of the stub (see `PaymentOrderServiceTest`).

## Webhook: Razorpay (`/webhooks/razorpay`) -- unauthenticated, signature-verified

Not under `/api/v1/public/**` -- its own permitAll pattern (`/api/v1/webhooks/**`, see `SecurityConfig`), since a webhook isn't public discovery data, it's an inbound call authenticated by an HMAC-SHA256 signature (`X-Razorpay-Signature` header) instead of a JWT. Returns 501 if no webhook secret is configured (`RAZORPAY_WEBHOOK_SECRET`), 400 if the signature doesn't verify, otherwise always 200 (a malformed or unrecognized payload is logged and ignored rather than making Razorpay retry forever). Safe to receive the same webhook twice -- `PaymentOrderService.handleWebhookPayload` is a no-op if the order is already `PAID`. On `payment.captured`, records a real `Payment` against the underlying Fee with `method: RAZORPAY` (reusing `FeeService`'s existing payment-recording path, receipt included).

This signature-verification + idempotent-processing logic is fully implemented and tested today (`RazorpaySignatureVerifierTest`, `PaymentOrderServiceTest.webhookProcessingRecordsAPaymentAndIsIdempotentOnRedelivery`) -- only the outbound "create an order" call needs real Razorpay credentials. See `docs/decisions.md` ADR-0019.

## Me: Device tokens (`/me/device-tokens`) -- Phase 13

Authenticated, any role. Registers a push-notification device token for the logged-in user.

| Method | Path | Notes |
|---|---|---|
| POST | `/me/device-tokens` | `{token, platform: ANDROID\|IOS\|WEB}` -- upsert by token (re-registering the same token updates it, including reassigning it to a different user if the same device logged in as someone else) |
| DELETE | `/me/device-tokens/{token}` | no-ops if the token isn't yours or is already gone -- never a 403, to avoid confirming/denying whether a token exists |

No client actually calls this yet -- see `docs/decisions.md` ADR-0020 for why (no Firebase project/credentials configured, so there's nothing real to register a token *for*).

## Notifications -- Phase 13

Not a REST resource -- `NotificationService.notifyUser(userId, title, message)` is called internally whenever something happens that a user should hear about: a booking is confirmed or cancelled (`BookingService`, both the student and the PG owner), an online payment is received (`PaymentOrderService`), a student files a complaint (the PG owner), or a complaint is marked resolved (the student). Delivery is push (to every registered device token) and email (if the user has one); failures for one recipient/channel are logged and swallowed, never allowed to fail the operation that triggered them. `LoggingNotificationGateway` is still the only external-delivery implementation -- live in-app SSE events work locally; see ADR-0020/ADR-0024.

## Me: live events stream (`/me/events/stream`) -- Phase 14

Authenticated, any role. `GET /api/v1/me/events/stream` -- Server-Sent Events, same transport shape as the public bed-availability stream (Phase 10) but per-user and behind auth instead of per-PG and public. Every call to `NotificationService.notifyUser` (see Notifications, above) now also publishes to this stream, so the same four trigger points -- booking confirmed/cancelled, payment received, complaint resolved -- get a live in-app echo for anyone with the app open right now, on top of the push/email delivery that already happened. Event payload: `{title, message, sentAt}`.

Flutter/dio-only client today (`LiveEventsListener`, wraps `StudentHomeScreen` and `PgListScreen`, shows a SnackBar per event) -- the browser `EventSource` API can't set an `Authorization` header, so the web app doesn't consume this yet (same constraint noted for booking/fee UI in ADR-0018/0019). See ADR-0021.

Same single-instance caveat as the Phase 10 stream (ADR-0016): the emitter registry is in-memory per backend instance, so this won't fan out correctly if the backend is ever horizontally scaled -- flagged there as the first thing to revisit if that happens, not solved here.

## Not yet built

WhatsApp notifications (explicitly deferred per the technical plan), production wiring for external integrations, and browser-side consumption of the live events stream (needs a cookie- or query-token-based auth path for `EventSource`, not attempted -- see ADR-0021). Add each new endpoint's contract here **before or alongside** implementation -- contract-first (CLAUDE.md).

## Flexible bookings, Razorpay, KYC, and settlement (current contract)

This section supersedes the older Phase 11/12 instant-booking and stub-payment descriptions above.

- Rooms are `MONTHLY`, `DAY_WISE`, or `MIXED`; mixed-room beds are `MONTHLY`, `DAY_WISE`, or `FLEXIBLE`. Room create/update also accepts `dayWiseRate`, `noticePeriodDays`, and `securityDeposit`. `PATCH /owner/beds/{bedId}/booking-mode` customizes a mixed-room bed.
- `GET /public/pgs/{pgId}?bookingType=MONTHLY|DAY_WISE&checkIn=YYYY-MM-DD&checkOut=YYYY-MM-DD` returns strict date-range availability plus booking/pricing/policy fields.
- `POST /student/bookings` accepts `{bedId, bookingType, checkInDate, checkOutDate?}` and creates a 10-minute `PAYMENT_PENDING` hold. Day-wise stays require checkout and are limited to 27 nights; monthly stays with a checkout are at least 28 nights.
- Booking status is `PAYMENT_PENDING|CONFIRMED|CHECKED_IN|COMPLETED|CANCELLED|EXPIRED`. A PostgreSQL exclusion constraint prevents overlapping active intervals on the same bed. Hourly stay transitions check in arrivals and complete departures.
- `GET /owner/rooms/{roomId}/calendar?from=&to=` returns owner-only entries with bed/customer/type/status/date range. `POST /student/bookings/{bookingId}/move-out-notice` stores the planned date and notice shortfall.
- `POST /student/bookings/{bookingId}/payment-orders` and `POST /student/fees/{feeId}/payment-orders` create/reuse Razorpay Checkout orders. `POST /student/payment-orders/{id}/verify` verifies the Checkout signature and captured state server-side. Payment response includes gateway key/order id and Route transfer status.
- Captured payments create a Razorpay Route transfer to the PG's verified linked account after commission. Booking transfers are held until after check-in. Route failures are retained as failed settlement records without undoing the customer payment. A late capture for an invalid hold initiates and tracks a full refund.
- `POST /student/autopay` accepts `{dueDay: 1..28}` and creates a monthly Razorpay Subscription mandate; the customer authorizes it once. Subsequent debits need no owner approval. Failure webhooks notify both parties. `GET /student/autopay` returns mandate/next-charge status.
- `POST /owner/fees/{feeId}/extensions` accepts `{newDueDate, note?}` and writes immutable extension history. Daily reminders are deduplicated and notify owner/customer on the effective due date and day three overdue.
- Deposit APIs: `GET /owner|student/bookings/{bookingId}/deposit`, `POST /owner/bookings/{bookingId}/deposit-deductions`, and `POST /owner/bookings/{bookingId}/deposit-refunds`. Deductions require an itemized reason; refunds use the original captured Razorpay payment.
- Owner phone verification: `POST /owner/profile/phone/otp/request` and `/verify`. KYC: `PUT /owner/pgs/{pgId}/kyc`, multipart `POST .../documents`, `POST .../submit`, and `GET .../kyc`. Required types are PAN card, Aadhaar front/back, owner photo, and PG photo. Only last four PAN/Aadhaar characters are stored in structured columns; document bytes go through private object storage.
- Admin KYC: `GET /admin/kyc/pending`, `PATCH /admin/kyc/{submissionId}`, and `GET /admin/kyc/documents/{documentId}/download-url`. Verification requires a Razorpay linked account and commission basis points. The web review console is `/admin/onboarding` and requires an ADMIN JWT.
- `/webhooks/razorpay` verifies the raw-body HMAC. Malformed JSON returns 400; processing failures become 5xx for gateway retry. Payment, subscription, transfer/refund, and deposit refund processing is idempotent.

Razorpay calls return 501 when API credentials are absent. KYC file operations use the private S3-compatible gateway when `S3_ENABLED=true`; with storage disabled they return 501, and metadata is never saved when byte storage fails. Downloads are exposed only through short-lived signed URLs.

## Customer profiles and direct-owner UPI (current contract)

All endpoints below require the role shown in the path. They use the authenticated principal; clients never submit an owner or customer user id.

### Customer profile and eligibility

| Method | Path | Notes |
|---|---|---|
| GET | `/student/profile` | Returns the customer's profile, verified-phone state, versioned legal acceptances, identity type, and identity last four characters. |
| PUT | `/student/profile` | `{fullName, occupation, permanentAddress?, identityType?, identityLast4?, acceptTerms, acceptPrivacy, acceptAadhaarConsent}`. `identityLast4` is exactly four characters; a full Aadhaar number is rejected. Aadhaar consent is separate and required only when `identityType=AADHAAR`. |
| POST | `/student/profile/phone/otp/request` | `{phone}`; requests verification for the profile mobile number. |
| POST | `/student/profile/phone/otp/verify` | `{phone, code}`; verifies that number for the authenticated customer. |
| GET | `/student/profile/booking-eligibility?bookingType=DAY_WISE\|MONTHLY` | Returns `{bookingType, eligible, missingRequirements}`. |

Both booking types require full name, occupation, current Terms acceptance, and current Privacy Notice acceptance. Monthly bookings additionally require a permanent address, identity type, and four-character identity suffix. The Flutter client still understands a `VERIFIED_MOBILE` requirement for compatibility with older deployments and can complete that verification through the profile screen. Booking creation enforces the server's current rules; the Flutter eligibility screen is not the security boundary.

### Owner direct-payment settings

| Method | Path | Notes |
|---|---|---|
| GET | `/owner/pgs/{pgId}/direct-payment-settings` | Returns `{pgId, enabled, beneficiaryName, upiId, mobileNumber, verified, verifiedAt}`. Unconfigured PGs return a disabled default. |
| PUT | `/owner/pgs/{pgId}/direct-payment-settings` | `{enabled, beneficiaryName, upiId, mobileNumber}`. Enabling requires the caller to own the PG, an approved PG KYC record, and an OTP-verified owner phone. |

The `verified` field means the platform's owner/KYC/phone prerequisites passed. It does not mean a bank or PSP independently verified the VPA. Direct payment is disabled by default.

### Customer direct-payment flow

| Method | Path | Notes |
|---|---|---|
| POST | `/student/bookings/{bookingId}/direct-payment-details` | Atomically selects `DIRECT_UPI` for the payment-pending booking, preventing a competing Razorpay order, and returns a no-store destination snapshot: `{bookingId, ownerName, upiId, maskedMobile, amount, currency, upiUri, paymentHoldExpiresAt}`. |
| GET | `/student/bookings/{bookingId}/direct-payment-details` | Recovers details only after direct payment was selected; it cannot be used to reveal an owner VPA before selection. |
| POST | `/student/bookings/{bookingId}/direct-payment-requests` | `{idempotencyKey, transactionReference, paymentConfirmed:true}`. Records the customer's claim and moves the booking to `DIRECT_PAYMENT_REVIEW`; it does not allocate or confirm the bed. |
| GET | `/student/bookings/{bookingId}/direct-payment-request` | Returns the authenticated customer's current request. `/direct-payment-requests/current` is an equivalent recovery route. |

`transactionReference` must be 6-100 characters containing only letters, digits, `.`, `_`, `/`, or `-`. The booking response exposes `paymentChannel: UNSELECTED|RAZORPAY|DIRECT_UPI`; direct-review bookings use status `DIRECT_PAYMENT_REVIEW`. All destination and amount values shown after selection are immutable request/booking snapshots.

### Owner review

| Method | Path | Notes |
|---|---|---|
| GET | `/owner/direct-payment-requests?pgId=&status=` | Lists only requests belonging to the authenticated owner. Status is `PENDING`, `APPROVED`, `REJECTED`, `REVIEW_OVERDUE`, or `CANCELLED`. |
| POST | `/owner/direct-payment-requests/{requestId}/approve` | `{amountReceived, idempotencyKey, note?}`. The amount must exactly equal the immutable quoted amount. Approval rechecks ownership, request state, hold, and bed overlap and confirms the booking in the same transaction. |
| POST | `/owner/direct-payment-requests/{requestId}/reject` | `{idempotencyKey, reason}`. Records an auditable rejection and releases the held booking. |

Customer submission never proves receipt. Only owner approval allocates the bed. Repeated decisions with the same idempotency key are safe, cross-owner access is rejected, and approved direct payments are included in owner dashboard/report collection totals by review time. Because funds bypass Razorpay, gateway reconciliation and automated gateway refunds are unavailable for this channel; production disputes and refunds must follow the operational policy in `direct-owner-payment-and-profile.md`.
