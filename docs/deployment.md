# Deployment (Phase 16)

Everything in this doc is preparation -- config, scripts, checklists -- not a live deployment.
No cloud account, domain, or paid service has been provisioned as part of building this
project; that's a decision only you can make (which provider, what budget), and every step
below that needs a real account is marked as an action item for you to carry out.

## Two deployment paths

Pick one. Both are equally valid for a pilot; the difference is how much you want to manage
yourself versus hand to a platform.

### Path A -- managed PaaS (least ops work, free/cheap tiers available)

- **Backend**: Railway or Render (Docker deploy from `backend/Dockerfile`), or Fly.io.
- **Database**: a managed Postgres -- Neon or Supabase's Postgres, or the PaaS's own bundled
  Postgres add-on. Any of them work as-is; Flyway doesn't care who's hosting the database.
- **Web app**: Vercel (built for Next.js, zero-config).
- **Mobile**: no hosting -- distribute the built APK/IPA via Firebase App Distribution or your
  app store's internal testing track.
- **Object storage** (once Phase 7b's stub is replaced): Cloudflare R2 or AWS S3.

Skip `infra/docker-compose.prod.yml` entirely on this path -- each platform builds
`backend/Dockerfile` (or the Next.js app) directly from your repo. What you still need from this
doc: the environment variable reference below, and the migration/rollback runbook.

**Reverse proxy / `X-Forwarded-For`**: every option above (Railway, Render, Fly, Vercel) already
terminates TLS and sets `X-Forwarded-For` correctly in front of your app, which is exactly what
`RateLimitFilter` (Phase 15) needs to trust that header safely -- no extra config needed on this
path.

### Path B -- self-hosted on a single VM

Use `infra/docker-compose.prod.yml` -- Postgres + backend + Caddy (automatic HTTPS) on one
machine (DigitalOcean, Hetzner, a bare EC2 instance, etc.). Steps:

1. Point a DNS A/AAAA record for your chosen domain (e.g. `api.yourdomain.com`) at the VM's IP.
2. `cp infra/.env.example infra/.env` and fill in every value -- the prod compose file has no
   dev fallbacks; a missing required variable fails the `docker compose up` outright rather than
   silently starting with an insecure default.
3. `cp infra/Caddyfile.example infra/Caddyfile`, replace the placeholder domain with your real
   one.
4. `docker compose -f infra/docker-compose.prod.yml up -d --build`
5. Deploy the Next.js web app separately (Vercel, or any Node host) -- it isn't part of this
   compose file. Point its `NEXT_PUBLIC_API_BASE_URL` at `https://api.yourdomain.com/api/v1`.

**Why Caddy specifically**: automatic Let's Encrypt HTTPS with no manual certbot/cron setup, and
it sets `X-Forwarded-For` itself on every proxied request (overwriting anything a client sent) --
which is what makes `RateLimitFilter` trustworthy on this path too. If you swap in a different
reverse proxy (nginx, Traefik), confirm it does the same before relying on the rate limiter.

## Environment variables

| Variable | Required in prod? | Notes |
|---|---|---|
| `SPRING_DATASOURCE_URL` / `_USERNAME` / `_PASSWORD` | Yes | Spring Boot's relaxed env binding maps these regardless of active profile -- point at your managed Postgres or the compose one. |
| `JWT_SECRET` | Yes | `application-prod.yml` has no dev fallback -- startup fails fast if unset. Generate with `openssl rand -base64 48`. Rotating it invalidates every existing access/refresh token (forces re-login) -- plan for that if you ever need to rotate it. |
| `CORS_ALLOWED_ORIGINS` | Yes | Comma-separated, no wildcard. Set to your deployed web app's real origin(s) only -- see `docs/security.md`. |
| `SPRING_PROFILES_ACTIVE` | Yes | Set to `prod`. |
| `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / `RAZORPAY_WEBHOOK_SECRET` | Only once you provision a Razorpay account | Blank = every payment endpoint that needs them returns 501 (ADR-0019). Not needed for a pilot that only records offline payments. |
| `GOOGLE_MAPS_API_KEY`, `GOOGLE_OAUTH_CLIENT_ID` / `_SECRET` | Only once provisioned | Same "blank = stub" pattern; Google OAuth login returns 501 until set (see `docs/decisions.md`). |
| `S3_ENDPOINT` / `S3_BUCKET` / `S3_ACCESS_KEY` / `S3_SECRET_KEY` | Only once Phase 7b's `DocumentStorageGateway` gets a real implementation | Document upload/download return 501 until then -- see ADR for Phase 7b. |
| `NEXT_PUBLIC_API_BASE_URL` (web app) | Yes | Your deployed backend's public URL + `/api/v1`. |
| `API_BASE_URL` (mobile, via `--dart-define`) | Yes, at build time | `flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1` -- see `mobile/lib/core/env.dart`. Baked into the binary; a URL change needs a rebuild, not a config change. |

`app.rate-limit.auth.*` and `app.otp.*` (Phase 1/15) have sane defaults in `application.yml` and
don't need overriding for a pilot -- see `docs/security.md` if you want to tune them.

## Database migrations

Flyway runs automatically on backend startup (`spring.flyway.enabled: true`,
`baseline-on-migrate: true` in `application.yml`) -- there is no separate "run migrations" step
to remember; deploying a new backend version *is* running its migrations, in order, exactly
once each (Flyway tracks applied versions in its own `flyway_schema_history` table).

**Before deploying a release that includes a new `V{n}__...sql` file**:
1. Take a Postgres backup first (see below) -- Flyway migrations in this project are
   append-only and forward-only (per `CLAUDE.md`'s numbering discipline), there is no built-in
   "undo migration N" command.
2. Review the migration for anything that locks a large table for a long time in production
   (an `ALTER TABLE ... ADD COLUMN ... NOT NULL` without a default can do this on a big table --
   none of this project's migrations do that so far, but check new ones against this before
   they ship).
3. Deploy. Watch the backend's startup logs for "Successfully applied N migration(s)" (Flyway's
   own log line) before considering the deploy complete.

**Rollback**: this project has no down-migrations (consistent with Flyway's own recommended
practice of forward-only migrations). If a bad migration ships, the fix is a new forward
migration that corrects it, not reverting the old one -- restore from backup only if data was
actually corrupted, not just to undo a schema change.

## Backups

Not automated by anything in this repo -- set up your provider's automated backups (every
managed Postgres option above has a "point-in-time recovery" or scheduled-snapshot feature) and
**verify you can actually restore from one** before going live, not just that backups exist. For
self-hosted Path B, a simple cron'd `pg_dump` to off-VM storage (S3/R2) is the minimum bar.

## Health checks and monitoring

- `GET /api/v1/health` and `GET /actuator/health` are both public (`SecurityConfig`) and cheap --
  use either for your platform's health-check / uptime-monitor config.
- Application logs go to stdout (standard Spring Boot behavior) -- your platform's log
  aggregation (Railway/Render/Fly all have one built in) captures them as-is, including the
  `AUDIT.document` / `AUDIT.payment` structured lines (Phase 15) and `GlobalExceptionHandler`'s
  now-logged unhandled exceptions. No separate log shipping setup exists in this repo.

## Pre-launch checklist

Carry these over from what Phase 15's audit flagged, since they're exactly the kind of thing
that's cheap to check before launch and expensive after:

- [ ] `JWT_SECRET` is a real random value, not the dev fallback, and is not committed anywhere.
- [ ] `CORS_ALLOWED_ORIGINS` is the real web app origin, not `localhost`.
- [ ] Reverse proxy (Caddy, or your PaaS's built-in one) actually sets `X-Forwarded-For` --
      confirm `RateLimitFilter` is seeing real client IPs, not all traffic collapsing onto one
      bucket (or being trivially spoofable) -- see `docs/security.md`.
- [ ] A Postgres backup has been taken and a **restore has been test-run** at least once.
- [ ] `mvn verify` and `flutter analyze` have both been run for real (nothing in this project has
      been compiler-verified in the environment it was built in -- see every phase's own notes).
- [ ] Dependency versions reviewed (`mvn versions:display-dependency-updates`) -- Spring Boot was
      pinned at 3.2.5 as of Phase 15 with no verified bump since; see `docs/security.md`.
- [ ] If launching with real payments: a Razorpay account is provisioned, `RAZORPAY_*` env vars
      are set, and the webhook URL is registered with Razorpay pointing at
      `https://<your-domain>/api/v1/webhooks/razorpay`.
- [ ] If launching with document uploads: an S3-compatible bucket is provisioned (private, no
      public read), `S3_*` env vars are set, and `StubDocumentStorageGateway` has been replaced
      with a real implementation (it isn't yet -- see the Phase 7b entry in `docs/decisions.md`).
