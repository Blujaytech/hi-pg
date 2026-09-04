# PG Management & Discovery Platform — Technical Plan

**Role of this document:** Lead Software Architect + Technical Project Manager brief. This organizes the existing product requirements (Owner app, Student app, live-sync bed booking, payments, complaints, reports, etc.) into a professional development structure, on the newly finalized tech stack. It supersedes the earlier React Native + Expo + Supabase prototype — that prototype's business logic, screen flows, and database schema shape remain valid reference material (they were built from the same requirements), but the implementation technology below is what the team builds on going forward.

Status: planning complete, implementation not started. No irreversible decisions have been made outside what's documented here.

---

## 1. Current Project Structure

What exists today, going into this phase:

```
pg-platform/                    (HTML clickable prototype — reference only)
  prototype.html                 Enterprise-grade responsive UI/UX reference for
                                  both Owner and Student flows, all screens, dark+light
                                  theme, validated interaction patterns.

pg-mobile-app/                  (React Native + Expo + Supabase — SUPERSEDED)
  src/screens/owner/...           Working implementation of the full owner flow
  src/screens/student/...         Working implementation of the full student flow
  supabase/schema.sql             A complete relational schema: profiles, pgs, floors,
                                   rooms, beds, payment_history, expenses, complaints,
                                   RLS policies, and a race-safe book_bed() RPC.
```

**What to actually reuse from this:**

- `prototype.html` — treat as the UX/visual specification. Every screen, state, and interaction (skeleton loading, confirm dialogs, validation, pagination, sort, recent searches) it demonstrates is a requirement the Flutter and Next.js apps should reproduce or improve on, not redesign from scratch.
- `pg-mobile-app/supabase/schema.sql` — treat as the **domain model specification**, not the literal schema. The entities, relationships, constraints, and especially the `book_bed()` atomic-claim logic are the correct design; they get re-expressed as PostgreSQL migrations owned by Spring Boot (via Flyway/Liquibase) instead of Supabase-managed SQL + RLS.
- The Expo/Supabase code itself (screens, navigation, Supabase client) — **not reused**. Flutter has no code-sharing path with React Native, and Spring Boot replaces Supabase's auto-generated API + RLS with real REST controllers + service-layer authorization. Keep the repo around for screen-by-screen reference during Flutter/Next.js implementation, then archive it.

---

## 2. Recommended Final Project Structure

A single monorepo, four workspaces, shared docs at the root. This keeps both developers able to see the whole system without needing four separate repos and four separate PR review contexts.

```
pg-platform/
├── mobile/                       Flutter app (Owner + Student, one codebase, two flows)
│   ├── lib/
│   │   ├── core/                 theme, constants, env config, http client, error handling
│   │   ├── auth/                 login, signup, JWT storage, OAuth/OTP
│   │   ├── owner/                feature-first: pg/, floor/, room/, bed/, student/,
│   │   │                         fee/, expense/, complaint/, document/, report/
│   │   ├── student/               search/, pg_details/, booking/, my_pg/, complaint/
│   │   ├── shared/                shared widgets, models, API client (generated or hand-rolled)
│   │   └── main.dart
│   ├── test/                      widget + unit tests, mirroring lib/ structure
│   └── pubspec.yaml
│
├── web/                          Next.js (marketing site + student web discovery + owner web console)
│   ├── app/                      App Router; route groups: (owner)/, (student)/, (public)/
│   ├── components/
│   ├── lib/                      API client, auth helpers
│   └── package.json
│
├── backend/                      Spring Boot (single service for v1 — see §7 on modular monolith vs microservices)
│   ├── src/main/java/com/pgplatform/
│   │   ├── auth/                  JWT issuance/validation, OAuth, OTP, role-based access
│   │   ├── owner/                  Owner, Pg, Floor, Room, Bed domain + REST controllers
│   │   ├── student/                Student profile, search, booking
│   │   ├── billing/                Fee, Payment, Receipt, Razorpay integration
│   │   ├── expense/
│   │   ├── complaint/
│   │   ├── document/               Aadhaar/photo upload, secure access
│   │   ├── notification/           push, email, WhatsApp
│   │   ├── report/
│   │   └── common/                 exceptions, validation, audit, security config
│   ├── src/main/resources/
│   │   └── db/migration/           Flyway migrations (V1__init.sql, V2__..., ...)
│   ├── src/test/                   unit + integration (Testcontainers against real Postgres)
│   └── pom.xml (or build.gradle.kts)
│
├── database/
│   └── er-diagrams/                kept in sync with db/migration
│
├── infra/                          docker-compose for local dev (Postgres, backend, web);
│                                   deployment configs (whichever host is chosen later)
│
├── docs/
│   ├── requirements.md
│   ├── architecture.md
│   ├── database.md
│   ├── api.md
│   ├── security.md
│   ├── development-workflow.md
│   └── decisions.md               ADR log — one entry per significant decision, dated
│
├── CLAUDE.md                       working agreements for AI-assisted development in this repo
└── README.md
```

**Why one repo, not four:** with two developers touching backend + both frontends in the same week, a monorepo means one PR can span "add endpoint" + "consume it in Flutter" when needed, one CI pipeline can enforce cross-cutting rules (e.g., "no direct SQL from mobile/web"), and `docs/` stays a single source of truth instead of drifting across repos. The cost — slightly heavier checkouts, need for path-based CI triggers — is small at this team size.

---

## 3. Technology Stack Confirmation

| Layer | Choice | Notes |
|---|---|---|
| Mobile (Owner + Student) | Flutter / Dart | Single codebase, two app "modes" gated by role after login — mirrors the existing Owner/Student navigator split from the prototype. |
| Web | Next.js / TypeScript | App Router, server components for public/SEO-relevant pages (student-facing PG search/listing), client components for authenticated dashboards. |
| Backend | Spring Boot / Java | Single deployable for v1 (see §7). REST, versioned (`/api/v1/...`). |
| Database | PostgreSQL | One database, schema-per-concern via package structure, not per-service. |
| Auth | JWT (access + refresh) + Google OAuth + OTP where appropriate | OTP for student phone-first signup (India-appropriate); Google OAuth as a faster path; owners likely email/password + OTP fallback. |
| Maps | Google Maps Platform | Confirm billing account before wiring in — Maps SDK has a free tier but is not unlimited; budget this. |
| Payments | Razorpay | India-focused, UPI support, well-documented webhooks — needed for idempotent payment processing (§ business rules). |
| Notifications | Push (FCM), Email (transactional provider — e.g. SES/Postmark/Resend), WhatsApp (Business API, later phase) | WhatsApp integration is the most operationally complex (Meta approval, template messages) — scope it as an explicit later phase, not v1. |
| File storage | Object storage (S3-compatible) for Aadhaar/documents/photos | Not listed explicitly in the original stack — flagging as a gap, see §7. |

Confirmed as final per your instruction — implementation proceeds on this stack.

---

## 4. Git Branch Strategy

Permanent branches: **`main`** (production-deployed, always releasable) and **`develop`** (integration branch, always green).

Everything else is a temporary feature branch off `develop`, named `feature/<scope>`, deleted after merge. Naming follows the functionality decomposition you listed, adjusted where the actual vertical slice differs:

```
feature/owner-auth
feature/student-auth              (split from owner-auth — different flows: OTP vs email, different roles)
feature/pg-management
feature/floor-management
feature/room-management
feature/bed-management
feature/owner-dashboard
feature/student-management
feature/fee-management
feature/expense-management
feature/complaint-management       (shared: both owner and student sides land under this branch's scope
                                    when developed together, or split into
                                    feature/complaint-owner-side / feature/complaint-student-side
                                    if the two developers need to parallelize it)
feature/document-management
feature/receipt-management
feature/reports
feature/student-search
feature/pg-details
feature/map-integration
feature/live-availability
feature/bed-selection
feature/booking
feature/payment-gateway
feature/notifications
feature/move-out
feature/security-deposit
feature/offline-payment
feature/bulk-pg-setup
```

Rules:

- No commits directly to `main` or `develop`. Every change is a PR from a feature branch into `develop`, reviewed (by the other developer or by a Claude instance acting as reviewer), then merged.
- `main` only receives merges from `develop` at release points, tagged (`v0.1.0`, `v0.2.0`, ...).
- A feature branch lives as long as the feature takes — days, not weeks. If a feature branch is open for more than ~5 working days, that's a signal it should have been split smaller.
- Migrations (Flyway `V__` files) are append-only and numbered globally — **the single highest-conflict-risk file type** in a two-developer setup. See §5 for the coordination rule.
- Branch protection on `develop` and `main`: require PR review, require CI (build + tests) to pass before merge.

---

## 5. Two-Developer Parallel Development Strategy

Both developers (and any Claude instance acting as one of them) have full repo access — frontend, mobile, backend, database, docs — but coordinate through branch ownership, not folder ownership. The goal is to avoid two people/agents editing the same file on different branches at the same time, because that produces merge conflicts that are expensive to resolve correctly (especially in generated files like migrations or route tables).

**Before starting any feature:**

1. Check `docs/decisions.md` and the current open branches (`git branch -r`) — has this area been touched recently, or is someone else on it?
2. Read the relevant existing code (backend module, Flutter feature folder, or Next.js route group) end to end before changing it.
3. Identify shared files this feature will likely touch — the most common are: `db/migration/` (new migration file — check the latest `V__` number first, right before creating yours, to avoid two branches both claiming `V12__`), the API route registry / OpenAPI spec, the shared Flutter `api_client.dart` or Next.js `lib/api.ts`, and `docs/api.md`.
4. If two features unavoidably touch the same shared file (e.g., both need to add a new field to the `User` DTO), post/note that explicitly and either sequence the two branches or agree on the shared change first as a tiny separate `feature/shared-user-dto-update` branch merged before both.
5. State the implementation plan (endpoints, tables touched, screens touched) before writing code — one paragraph is enough — so the other developer can flag overlap early rather than at merge time.

**Division of work that minimizes collision, given the dependency graph in §6:**

- Backend and one frontend can usually proceed in parallel once an API contract (even a stub/mock) exists for a feature — agree the request/response shape in `docs/api.md` first, then backend and Flutter/Next.js build against that contract independently, wiring up for real once both are ready. This is the single highest-leverage practice for two developers: **contract first, implementation in parallel.**
- Prefer splitting by *vertical feature* (one dev takes `feature/room-management` end-to-end: migration + endpoint + Flutter screen + web screen if applicable) over splitting by *layer* (one dev "does all backend," the other "does all frontend") — layer-splitting maximizes the number of PRs that touch the same files at the same time.
- Migrations: whoever's branch merges to `develop` first "wins" the next migration number; the second developer rebases and renumbers before merging. Never merge two branches with the same `V__` number.

---

## 6. Development Phases / Sprints

The order you proposed is close to correct and dependency-sound; two adjustments below (marked ⚠) and the reasoning for keeping the rest.

**Phase 0 — Project Foundation** (days, not a sprint)
Monorepo scaffold, CI (build + test on PR), Postgres running via docker-compose, Spring Boot skeleton with health check, Flutter skeleton with a login screen shell, Next.js skeleton with a landing page, `docs/` seeded with this plan.

**Phase 1 — Auth & Authorization**
JWT issuance/refresh, role model (OWNER / STUDENT, extensible for e.g. future STAFF role), Google OAuth, OTP flow, password reset. ⚠ Split owner and student auth into two feature branches (different UX: owner is likely email-first, student is likely phone/OTP-first) even though they share backend auth infrastructure.

**Phase 2 — Owner Core: PG → Floor → Room → Bed**
The hierarchical structure management, with bed auto-creation from room "sharing" count (as the prototype does). This is the foundation everything else (students, fees, bookings) hangs off of, so it correctly comes right after auth.

**Phase 3 — Owner Dashboard**
Depends on Phase 2 existing data to aggregate; thin at first (counts, occupancy %), grows richer once fees/payments exist (Phase 5).

**Phase 4 — Student Management (owner-side: add/view students manually, independent of booking flow)**
Needed before fee management, since fees attach to a student+bed.

**Phase 5 — Fee Management, Phase 5b — Expense Management**
Can run in parallel with each other (low coupling) once Phase 4 is done — good candidate for the two developers to split.

**Phase 6 — Complaint Management**
Low coupling to billing; can be developed in parallel with Phase 5 if capacity allows.

**Phase 7 — Documents & Receipts**
⚠ Move this earlier than your original order relative to reports, and explicitly split into two concerns: (a) **document storage** (Aadhaar/photo upload — needs object storage wired in, and is a security-sensitive feature worth isolating and hardening early rather than bolting on later) and (b) **receipts** (generated from Fee/Payment records, so it genuinely depends on Phase 5 being done — this part stays where you had it).

**Phase 8 — Reports**
Now has fees, expenses, and occupancy data to report on.

**Phase 9 — Student Discovery: Search, PG Details, Maps**
First student-facing feature. Search and PG details can start as soon as Phase 2's data exists (a PG with floors/rooms/beds is searchable even before booking works) — this is a good place to bring the Next.js web app online in parallel with continued Flutter work.

**Phase 10 — Live Bed Availability**
This is a cross-cutting concern (owner changes a bed's status → student view must reflect it) — implement it as its own phase with a clear technical decision made up front (see §7: WebSocket/SSE vs polling) rather than retrofitting it per-screen.

**Phase 11 — Student Registration & Bed Selection/Booking**
The critical-path business rule ("two students must never book the same bed") lands here. This phase should include a written concurrency test (two simulated simultaneous booking requests against one bed) as an explicit acceptance criterion, not just code review.

**Phase 12 — Payment Gateway (Razorpay)**
Depends on booking existing (a booking is what a payment attaches to) and must be designed idempotent from the start (§ business rules) — webhook handling with idempotency keys, not just "call Razorpay and hope."

**Phase 13 — Notifications**
Push first (cheapest, fastest feedback loop), email second, WhatsApp explicitly deferred to its own later phase given Meta Business API approval lead time.

**Phase 14 — Real-time Synchronization (broader than bed availability)**
Extend the Phase 10 mechanism to complaints/payments-updated-live if desired — genuinely optional for v1 pilot; flag as a candidate to cut if timeline is tight.

**Phase 15 — Testing & Security Hardening**
Not actually a phase that happens only at the end — see §8 on why every phase above should carry its own tests, and treat this phase as a dedicated pass (penetration-test-style review, load test on booking concurrency, RLS-equivalent authorization audit) before pilot.

**Phase 16 — Pilot Deployment**

---

## 7. Missing Requirements & Technical Risks

Flagging these now because each is cheaper to decide before code exists than after:

1. **File/object storage is unspecified in the finalized stack.** Documents (Aadhaar, photos) need somewhere to live outside Postgres. Needs a decision: S3 directly, or a managed equivalent, with signed-URL access so Spring Boot controls who can fetch a given document (never a public bucket).
2. **Modular monolith vs. microservices for the backend.** Your architecture note says "both use the same Spring Boot backend" (singular) — recommend building it as **one Spring Boot deployable, internally organized into the package-per-domain structure in §2** (a "modular monolith"), not separate microservices per domain. At pilot scale, microservices add deployment/ops complexity (service discovery, distributed transactions for things like "booking + payment") without a corresponding benefit; the package boundaries in §2 already give you the option to split into real services later if a specific module needs independent scaling.
3. **Live-sync transport mechanism is undecided.** The prototype and Supabase build both relied on realtime push. Spring Boot options: WebSocket (STOMP), Server-Sent Events, or client polling with a short interval. Recommend **SSE for bed-availability updates** (simpler than WebSocket for a mostly-server-to-client feed, no extra broker needed at this scale) with a documented fallback to polling if a client can't hold a persistent connection. This should be an explicit architecture decision recorded in `docs/decisions.md` before Phase 10.
4. **Idempotent payments needs a concrete mechanism, not just a principle.** Recommend: client generates an idempotency key per booking/payment attempt, backend stores it with a unique constraint, Razorpay webhook handler is itself idempotent (safe to receive the same webhook twice — Razorpay explicitly recommends designing for this). Write this into `docs/security.md` as a concrete flow before Phase 12.
5. **Soft-delete / audit trail needs a standard pattern, decided once.** "Student records should not be hard-deleted" implies every relevant table needs a `status`/`deleted_at` convention and every query needs to respect it — decide this as a shared base entity pattern in Phase 0/1, not per-table later.
6. **Row-level authorization without RLS.** Supabase gave you Postgres RLS for free; Spring Boot doesn't have an equivalent unless you add one (e.g., Hibernate filters, or — more robust — enforce every "owner can only touch their own PG's data" and "student can only see their own private data" check explicitly in the service layer with tests for it). This is a security-critical gap to design deliberately, not assume, since raw JPA queries by default won't scope by owner automatically.
7. **Rate limiting / abuse prevention** for OTP endpoints specifically (SMS OTP is a cost-per-send target for abuse) isn't in the original requirements — recommend adding.
8. **Map provider cost.** Google Maps Platform requires a billing account attached even within free-tier limits; confirm this is acceptable before Phase 9, or evaluate Mapbox/OpenStreetMap-based alternatives as a lower-commitment option for a pilot.
9. **Environment/secrets management** across four workspaces (mobile, web, backend, infra) isn't specified — recommend a single documented convention (e.g., `.env.example` per workspace, secrets never committed, a secrets manager for anything beyond local dev) written into `docs/development-workflow.md` in Phase 0.
10. **WhatsApp Business API lead time.** Meta's approval process for template messages can take days to weeks — if WhatsApp is wanted for pilot, start that approval process in parallel with early phases rather than waiting until Phase 13.

---

## 8. Recommended Improvements Beyond Original Requirements

- **Contract-first API development** (§5) — write `docs/api.md` entries (or an OpenAPI spec generated from Spring annotations) before frontend implementation starts on any feature, so Flutter/Next.js can build against a stub.
- **Testcontainers for backend integration tests** — run tests against a real ephemeral Postgres, not H2/mocks, so migration + query behavior is verified for real, especially for the booking concurrency test in Phase 11.
- **A dedicated concurrency test for bed booking** as a first-class, named test (not just manual QA) — two simulated concurrent requests, assert exactly one succeeds — since this is the platform's core trust guarantee.
- **Structured audit logging** for anything touching student documents or payments (who accessed what, when) — goes beyond "secure storage" to "provable who-accessed-it," which matters for a product handling Aadhaar numbers.
- **API versioning from day one** (`/api/v1/...`) even though there's only one version now — costs nothing now, avoids a painful migration later once the web and mobile clients are both live and can't be forced to upgrade simultaneously.
- **A staging environment** (not just local + prod) before pilot deployment, so Razorpay/Maps/notification integrations can be tested against real-but-non-production credentials.
- **Decisions log discipline** (`docs/decisions.md`) — every item in §7 that gets resolved should get one dated entry: the decision, the alternatives considered, why. This is what lets a second developer (or a future Claude session with no memory of this conversation) understand *why* the codebase looks the way it does, not just what it does.

---

## 9. Immediate Next 5 Development Tasks

1. **Scaffold the monorepo** per §2 — empty but building Flutter app, Next.js app, Spring Boot app, docker-compose Postgres, CI pipeline that runs on every PR. No features yet; the goal is "everything builds and deploys locally" as the Phase 0 exit criterion.
2. **Write `docs/database.md` and the first Flyway migration** — translate the Supabase schema (`pg-mobile-app/supabase/schema.sql`) into the base entity pattern from §7 item 5 (soft-delete convention, audit columns) as PostgreSQL DDL, covering `users`, `pgs`, `floors`, `rooms`, `beds` only (enough for Phase 2).
3. **Implement Phase 1 (Auth) end to end for the Owner role first: signup, login, JWT issue/refresh, one protected endpoint to prove role-based authorization works — this unblocks every other feature branch.**
4. **Write `docs/api.md`'s first entries and `docs/security.md`'s authorization model** — specifically, document the "owner can only touch their own PG" and "student privacy" enforcement pattern from §7 item 6, since every subsequent feature depends on getting this pattern right once rather than reinventing it per-endpoint.
5. **Start Phase 2 (PG → Floor → Room → Bed) on the backend**, in parallel with the second developer starting the corresponding Flutter Owner screens against the API contract from task 4 — the first real test of the contract-first, parallel-branch workflow from §5.

---

*Prepared as a planning document, not yet reflected in code. Once you confirm this structure (or note adjustments), the next step per your instructions is implementing one feature at a time, starting with the tasks in §9.*
