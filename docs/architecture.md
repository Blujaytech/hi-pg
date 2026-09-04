# Architecture

## Shape

One Spring Boot deployable ("modular monolith"), package-per-domain, backing a Flutter mobile app (Owner + Student) and a Next.js web app (public discovery + owner console). See ADR-0001 in `decisions.md` for why not microservices.

```
Flutter app  ---\
                 >---  Spring Boot REST API (/api/v1/...)  ---  PostgreSQL
Next.js web  ---/
```

## Backend package layout (`backend/src/main/java/com/pgplatform/`)

- `common/` -- `BaseEntity` (soft-delete + audit convention), exceptions, `GlobalExceptionHandler`, JPA auditing config, health endpoint.
- `auth/` -- users, roles, JWT issuance/validation/refresh, owner email+password auth, student phone+OTP auth, password reset, Google OAuth (stub), Spring Security config.
- `owner/` -- Pg → Floor → Room → Bed hierarchy, ownership authorization (`OwnershipGuard`), bed auto-creation.
- `student/`, `billing/`, `expense/`, `complaint/`, `document/`, `notification/`, `report/` -- scaffolded package directories for phases not yet built. `notification/` has a real interface (`NotificationGateway`) with a logging stub implementation, used today by OTP and password-reset flows.

Every request is versioned under `/api/v1/`. Authentication is stateless JWT (`Authorization: Bearer <token>`), validated per-request by `JwtAuthFilter` -- no server-side session state.

## Data model

See `database.md`. Every table follows the same convention: UUID primary key, `created_at`/`updated_at`/`created_by`/`updated_by`/`deleted_at`, soft-delete only.

## Authorization model

There is no Postgres RLS (the prototype's Supabase setup had this for free; Spring Boot does not get it automatically). Every service method that touches an owner's data explicitly verifies the resource's owner chain matches the authenticated principal (`OwnershipGuard`), before any read or write. See `security.md`.

## Real-time / live sync (not yet built)

Recommended and pending (Phase 10): Server-Sent Events for bed-availability push, with polling fallback. Not needed until student discovery + booking exist. Decision to be finalized and logged in `decisions.md` before that phase starts.

## Client apps

- **Flutter (`mobile/`)** -- one codebase, role-gated at runtime after login (`app_router.dart` redirects Owner vs Student). `lib/shared/api_client.dart` is the single Dio instance every feature repository uses; it attaches the JWT and does one silent refresh-and-retry on a 401.
- **Next.js (`web/`)** -- App Router, route groups `(public)/`, `(owner)/`, `(student)/`. Server components intended for the eventual SEO-relevant student discovery pages; today it's a landing page + two placeholder route groups. `lib/api.ts` is the equivalent single fetch wrapper.
