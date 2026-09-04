# Database

PostgreSQL, one database, managed by Flyway migrations under `backend/src/main/resources/db/migration/`. Numbered globally and append-only -- see CLAUDE.md for the two-developer coordination rule on this file set.

## Convention: every table

```sql
id          uuid primary key,
...
created_at  timestamptz not null default now(),
updated_at  timestamptz not null default now(),
created_by  uuid,
updated_by  uuid,
deleted_at  timestamptz
```

`deleted_at is null` means "live row". Nothing is ever hard-deleted by application code (see `BaseEntity`/`OwnershipGuard` in `architecture.md`). `created_by`/`updated_by` are populated by Spring Data JPA auditing (`JpaAuditingConfig`) from the authenticated principal, when there is one (system/anonymous operations leave them null).

## V1 -- `auth` (see `V1__init_auth.sql`)

- `users` -- one table for both Owner and Student roles (`role` column). `email` XOR/AND `phone` (at least one required, both unique when present). `password_hash` is null for OTP-only students.
- `refresh_tokens` -- opaque refresh tokens, only the SHA-256 hash stored, revocable.
- `otp_codes` -- hashed OTP codes for student phone auth, purpose-scoped, attempt-limited.
- `password_reset_tokens` -- hashed reset tokens, single-use.

## V2 -- `owner` hierarchy (see `V2__owner_pg_floor_room_bed.sql`)

```
pgs (owner_id -> users)
 └── floors (pg_id -> pgs)
      └── rooms (floor_id -> floors)  [sharing_count, rent_per_bed, room_type]
           └── beds (room_id -> rooms)  [label, status: AVAILABLE|OCCUPIED|MAINTENANCE]
```

**Bed auto-creation**: creating a Room with `sharing_count = N` creates exactly N beds (`Bed 1`..`Bed N`), `AVAILABLE`. Changing `sharing_count` on update grows (adds `AVAILABLE` beds) or shrinks (soft-deletes the highest-numbered `AVAILABLE` beds first; refuses if there aren't enough non-occupied beds to remove). See `RoomService.syncBedsToSharingCount` and its test, `RoomBedAutoCreationTest`.

## ER diagram

Keep `database/er-diagrams/` in sync whenever a migration changes the shape. Not yet generated for V1/V2 -- add one (dbdiagram.io, or `pg_dump --schema-only` piped through a diagramming tool) before Phase 4 adds enough tables that the shape stops being obvious from the migrations alone.

## V3 -- students (see `V3__students.sql`)

```
students (pg_id -> pgs, bed_id -> beds nullable)
```

A student is an owner-managed **record**, not a login (`users` row) -- Phase 11 (self-service booking) will decide how a real Student login connects to one of these, if at all; don't assume today's shape is final. `bed_id` is nullable (a student can exist before being placed), and a partial unique index (`uq_students_active_bed`) enforces "one active student per bed" at the DB level as defense-in-depth alongside the equivalent check in `StudentService.doAssignBed`.

`idProofNumber` is a plain varchar column today -- there is no encryption-at-rest or access-logging layer yet. Revisit before this table holds real Aadhaar numbers in anything but a dev database (technical plan §7 item 1, `docs/security.md`).

## V4 -- fees & payments (see `V4__fees_and_payments.sql`)

```
fees (student_id -> students, pg_id -> pgs [denormalized off student.pg])
 └── payments (fee_id -> fees)
```

One `fees` row per student per billing period -- `uq_fees_student_period` (unique on `student_id, period_year, period_month` where live) enforces that at the DB level; `FeeService.create` checks it proactively first so the error is a clean 409, not a raw constraint-violation 500. `fees.status` (`PENDING`/`PARTIALLY_PAID`/`PAID`) is recomputed from the sum of its `payments` every time one is recorded -- it is *not* itself the source of truth for "how much is owed"; the API always returns `amountPaid`/`balance` computed from the live payments list. "Overdue" is never stored (see `api.md`).

`pg_id` on `fees` is denormalized off `student.pg_id` purely so `/owner/pgs/{pgId}/fees` and the dashboard sums don't need an extra join through `students`. If a "move a student to a different PG" feature is ever added, it must update `fees.pg_id` for that student's fees too, or this denormalization silently rots -- see ADR in `decisions.md`.

## V5 -- expenses (see `V5__expenses.sql`)

```
expenses (pg_id -> pgs)
```

Standalone, no FK to `fees`/`payments` -- low coupling per the technical plan §6 (Phase 5b can be built independently of Phase 5).

## V6 -- complaints (see `V6__complaints.sql`)

```
complaints (student_id -> students, pg_id -> pgs [denormalized off student.pg, same caveat as Fee -- ADR-0008])
```

Owner-logged only today (`docs/decisions.md`). `resolved_at` is maintained by `ComplaintService.updateStatus` (set on entering `RESOLVED`/`CLOSED`, cleared otherwise) -- never written directly.

## V7 -- receipts (see `V7__receipts.sql`)

```
receipt_number_seq (sequence)
receipts (payment_id -> payments, unique; student_id -> students; pg_id -> pgs [denormalized, same caveat as Fee/Complaint])
```

One receipt per payment (`unique` on `payment_id`), generated by `ReceiptService.generateFor` inside the same transaction as `FeeService.recordPayment`. `receiptNumber` is drawn from `receipt_number_seq` via a native `nextval(...)` query rather than a Java-side counter, so it stays correct under concurrent payments across different owners/PGs without extra locking. `studentNameSnapshot`, `pgNameSnapshot`, `feePeriodMonth`, `feePeriodYear` are copied at insert time rather than joined live -- a receipt's displayed content never changes after issue, even if the student is renamed or the fee record is edited later.

## V8 -- documents (see `V8__documents.sql`)

```
documents (student_id -> students, storage_key nullable)
```

Metadata-only table. `storage_key` stays `NULL` for every row today because `StubDocumentStorageGateway` throws on every call -- `DocumentService.upload` calls the gateway *before* inserting a row, so no row is ever created with a null/broken key; the column is nullable only because the schema needs to exist ahead of real storage being wired in (contract-first, CLAUDE.md).

## V9 -- student login/record linkage + bookings (see `V9__student_booking.sql`)

```
students.user_id -> users (nullable, unique)
bookings (student_id -> students, bed_id -> beds, pg_id -> pgs [denormalized off bed's PG])
```

`students.user_id` is the first link between a Student login and a Student record -- see `docs/decisions.md` ADR-0018 for how/when it gets populated (only via booking, today). `uq_bookings_bed_confirmed` (unique on `bed_id` where `status = 'CONFIRMED' and deleted_at is null`) is defense-in-depth for the "one bed, one confirmed booking" guarantee -- the actual enforcement is a Postgres row lock in `BookingService.book`, see ADR-0017.

## V10 -- payment orders (see `V10__payment_orders.sql`)

```
payment_orders (fee_id -> fees, idempotency_key unique, razorpay_order_id unique, razorpay_payment_id unique)
```

Tracks one attempt to pay a Fee online. `uq_payment_orders_idempotency_key` is the DB-level half of the idempotency mechanism (technical plan §7 item 4) -- `PaymentOrderService.createOrder` also checks for an existing row with the same key before ever calling the (stubbed) Razorpay gateway. No `Payment` row is created until the Razorpay webhook reports `payment.captured`; see `docs/decisions.md` ADR-0019.

## V11 -- device tokens (see `V11__device_tokens.sql`)

```
device_tokens (user_id -> users, token unique)
```

One row per registered push-capable device. Upserted by `token` (`DeviceTokenService.register`) so the same physical device re-registering doesn't pile up duplicate rows, and gets reassigned if a different account logs in on it later. No row can meaningfully receive a push yet -- see `docs/decisions.md` ADR-0020.

## What's still missing (not yet migrated)

Phase 14 added no schema (pure in-memory SSE fan-out, no new tables). Everything past Phase 14. Gets its own `V{n}__...sql` when that phase starts -- check the latest `V` number in the migration folder first (CLAUDE.md).
