# Hi PG — Management, Discovery, Booking, and Payments Platform

Hi PG is an Android-first platform for paying-guest accommodation. Customers can discover PGs, inspect live room and bed availability, book monthly or day-wise stays, pay online or directly to an owner, and manage their stay. Owners can operate properties, rooms, beds, customers, fees, expenses, complaints, KYC, and reports. Platform administrators review KYC, seed unclaimed listings, approve ownership claims, and handle support requests.

This repository is a deployable monorepo containing a Flutter application, Spring Boot API, PostgreSQL schema and migrations, Next.js web application, and deployment configuration.

> **Current state (October 2026):** the core product flows are implemented through Flyway migration `V28`. The checked-in Render Blueprint is useful for development or a controlled pilot. A public production launch still requires production cloud accounts, paid database backups, approved legal documents, restricted credentials, release signing, live Razorpay/Firebase configuration, monitoring, and store review.

## Table of contents

- [What has been implemented](#what-has-been-implemented)
- [Architecture and technology](#architecture-and-technology)
- [Repository structure](#repository-structure)
- [Local development](#local-development)
- [Configuration and secrets](#configuration-and-secrets)
- [Testing](#testing)
- [Deployment](#deployment)
- [Access and account setup](#access-and-account-setup)
- [Privacy, permissions, and Play Store declarations](#privacy-permissions-and-play-store-declarations)
- [Security and operations](#security-and-operations)
- [Known production-readiness gaps](#known-production-readiness-gaps)
- [Release checklist](#release-checklist)
- [Documentation](#documentation)

## What has been implemented

### Customer experience

- Guest browsing of public PG listings without authentication.
- Search by city/area, nearby discovery using device location, audience and stay-type filters.
- Property details with photos, facilities, address, native Google Map, directions, room/bed prices, and live availability.
- Customer authentication using phone OTP/Firebase Phone Authentication or Google Sign-In.
- Secure access-token and rotating refresh-token sessions.
- Customer profile, guardian/contact information, profile photo, versioned Terms and Privacy Notice acceptance.
- In-app account deletion with session revocation, personal-data anonymization, private-file cleanup, and public deletion instructions.
- Monthly and day-wise bookings with explicit check-in/check-out dates.
- Specific-bed selection and a visible ten-minute payment-hold countdown.
- Database-enforced protection against overlapping active bookings.
- Razorpay Checkout, captured-payment verification, webhook processing, refunds for stale holds, Route settlements, and optional AutoPay.
- Optional direct-owner UPI or cash claims, with owner review and immutable payment details.
- Fees, receipts, deposits, deductions, move-out notices, booking cancellation, and payment status.
- Customer-created PG complaints routed to the correct owner.
- Separate Help & Support tickets routed to the platform admin.
- Authenticated real-time events and reconnecting live-availability streams.

### Owner experience

- Owner email/password registration, login, password reset, and role-gated screens.
- Property, floor/block, room, and bed management.
- Monthly, day-wise, and mixed inventory with per-room/per-bed pricing and availability.
- PG photo gallery, location, audience, facilities, and operational details.
- Customer roster derived from authoritative bookings, including active, moved-out, and pending customers.
- Fee generation, offline payment records, receipts, expenses, deposits, and financial/occupancy reports.
- Direct-payment review queue with atomic approve/reject actions.
- Complaint management from open through resolution.
- Owner/PG KYC submission, private document uploads, and payment-account onboarding.
- Mobile-number-based claim flow for listings initially created by an admin.
- Platform Help & Support tickets.

### Platform admin experience

- Server-authorized `ADMIN` role; there is no public admin signup.
- Add real PG listings as unclaimed and unverified without creating fake owner credentials.
- Match invited owners by verified mobile number.
- Review owner/PG KYC using short-lived signed document URLs.
- Approve or reject ownership claims and control when a listing becomes bookable.
- Process customer and owner support tickets.
- Supervise platform onboarding and payment-account details.

### Backend and data guarantees

- Modular-monolith Spring Boot API under `/api/v1`.
- PostgreSQL with append-only Flyway migrations; the current schema reaches `V28__account_deletion_and_identity_cleanup.sql`.
- Soft deletion and audit metadata for domain records.
- Explicit service-layer ownership checks for owner/customer data.
- JWT access tokens plus opaque, hashed, rotating refresh tokens.
- Per-phone OTP controls and per-IP authentication rate limiting.
- PostgreSQL row locks and constraints for booking/payment concurrency.
- Idempotent payment orders, direct-payment requests, and webhook handling.
- Private S3-compatible document storage with short-lived signed reads.
- Structured access logs for sensitive document and payment operations.
- Server-Sent Events for public availability and authenticated user updates.
- Flyway migrations applied automatically when the backend starts.

## Architecture and technology

| Layer | Current implementation |
|---|---|
| Mobile | Flutter/Dart, Android-first, one app with customer, owner, and admin routing |
| Backend | Java 17, Spring Boot 3.2.5, Spring Security, Spring Data JPA |
| Database | PostgreSQL and Flyway migrations |
| Web | Next.js 16.3.5, React 18, TypeScript, Tailwind CSS |
| Authentication | Platform JWT/refresh tokens, Firebase Phone Authentication, Google ID tokens |
| Payments | Razorpay Checkout, Route, Subscriptions/AutoPay, and direct-owner claims |
| Maps | Google Maps SDK for Android and device geolocation |
| Documents | Private S3-compatible storage; Cloudflare R2 is the current deployment choice |
| Notifications | Firebase/FCM integration plus authenticated SSE; provider configuration is environment-specific |
| Pilot deployment | Render Docker service + PostgreSQL via `render.yaml` |
| Recommended production | Cloud Run + Cloud SQL + Secret Manager + Artifact Registry, with Vercel for web |

The backend is intentionally a single deployable modular monolith. Before running more than one API instance, move scheduled work to an external scheduler and use a shared event system such as Pub/Sub or Redis; the current live-event broadcaster is in memory.

## Repository structure

```text
hi_pg/
├── backend/       Spring Boot API, Dockerfile, Flyway migrations, and tests
├── mobile/        Flutter Android application
├── web/           Next.js public web application and owner/admin scaffolding
├── database/      Database diagrams and supporting files
├── docs/          API, security, architecture, decisions, and deployment guides
├── infra/         Local and self-hosted Docker Compose configuration
├── render.yaml    Render Blueprint for the pilot API and PostgreSQL
└── README.md      Project overview and launch entry point
```

## Local development

### Prerequisites

- JDK 17+
- Maven 3.9+
- Node.js 20+
- Flutter 3.x and Android SDK
- Docker Desktop with Docker Compose
- An Android emulator or physical Android device for mobile testing

### 1. Configure local environment

Copy the example file and replace development placeholders as needed. Never commit the resulting `.env` file.

```powershell
Copy-Item infra\.env.example infra\.env
```

Credentials for Razorpay, Google/Firebase, Maps, and object storage may remain blank when the corresponding integration is not being tested. Disabled external integrations return an explicit error rather than silently pretending to work.

### 2. Start PostgreSQL and the backend

```powershell
Set-Location infra
docker compose up -d

Set-Location ..\backend
mvn spring-boot:run
```

Backend health endpoints:

- API health: `http://localhost:8080/api/v1/health`
- Actuator health: `http://localhost:8080/actuator/health`

Flyway applies pending migrations during startup.

### 3. Start the web application

```powershell
Set-Location web
npm install
npm run dev
```

Open `http://localhost:3000`. The local default API URL is `http://localhost:8080/api/v1`; it can be overridden in `web/.env.local`:

```dotenv
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080/api/v1
```

### 4. Run the Flutter application

```powershell
Set-Location mobile
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

`10.0.2.2` is the Android emulator route to the host computer. A physical device must use a reachable LAN or HTTPS API address.

For Google Sign-In, pass the same Web OAuth client ID used by the backend:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1 `
  --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Add the Android Maps SDK key to the uncommitted `mobile/android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=your-android-restricted-key
```

Firebase Android configuration belongs at `mobile/android/app/google-services.json`. Do not place a Firebase service-account private key in the app or repository.

## Configuration and secrets

### Backend deployment variables

| Variable | Requirement | Purpose |
|---|---|---|
| `SPRING_PROFILES_ACTIVE=prod` | Production | Enables production configuration |
| `PORT` | Hosting platform | HTTP port; Render/Cloud Run normally supplies it |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | Render Blueprint | PostgreSQL connection values |
| `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | Alternative database setup | Direct Spring datasource override |
| `JWT_SECRET` | Required | Signs platform tokens; generate a strong random secret |
| `CORS_ALLOWED_ORIGINS` | Required for web | Exact comma-separated HTTPS origins; never use `*` in production |
| `LEGAL_OPERATOR_NAME`, `LEGAL_SUPPORT_EMAIL`, `LEGAL_POSTAL_ADDRESS` | Required | Verified identity/contact rendered on public privacy, terms, and deletion pages |
| `GOOGLE_OAUTH_CLIENT_ID` | Google login | Web OAuth client ID accepted as the token audience |
| `FIREBASE_ENABLED` | Firebase auth/push | Enables backend Firebase verification and delivery |
| `FIREBASE_PROJECT_ID` | When Firebase is enabled | Firebase project used for identities and FCM |
| `RAZORPAY_KEY_ID` | Online payments | Razorpay public key identifier |
| `RAZORPAY_KEY_SECRET` | Online payments | Razorpay private API credential |
| `RAZORPAY_WEBHOOK_SECRET` | Online payments | Verifies `/api/v1/webhooks/razorpay` callbacks |
| `RAZORPAY_API_BASE_URL` | Optional | Defaults to `https://api.razorpay.com` |
| `S3_ENABLED=true` | Documents/photos | Enables real S3-compatible storage |
| `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET` | Documents/photos | Storage location and bucket |
| `S3_ACCESS_KEY`, `S3_SECRET_KEY` | Documents/photos | Private storage credentials |
| `S3_PATH_STYLE_ACCESS` | Provider-specific | Addressing mode for the S3-compatible provider |

### Client build variables

| Variable | Client | Purpose |
|---|---|---|
| `NEXT_PUBLIC_API_BASE_URL` | Web | Public API URL ending in `/api/v1` |
| `API_BASE_URL` | Flutter `--dart-define` | API URL baked into the mobile binary |
| `GOOGLE_OAUTH_WEB_CLIENT_ID` | Flutter `--dart-define` | Must match backend `GOOGLE_OAUTH_CLIENT_ID` |
| `GOOGLE_MAPS_API_KEY` | Android build | Android-restricted Maps SDK key |

Never commit `.env`, `local.properties`, `key.properties`, keystores, database passwords, JWT secrets, Razorpay secrets, S3/R2 credentials, or service-account JSON keys. Public identifiers such as OAuth client IDs still need environment separation and provider-side restrictions.

## Testing

Run checks before every deployment:

```powershell
# Backend
Set-Location backend
mvn test

# Mobile
Set-Location ..\mobile
flutter analyze
flutter test

# Web
Set-Location ..\web
npm ci
npm run lint
npm run build
npm audit
```

Backend integration tests use PostgreSQL/Testcontainers. Docker must be available. High-risk scenarios include booking concurrency, payment idempotency, cross-owner/customer authorization, webhook redelivery, signed-document access, and migrations.

## Deployment

### Recommended production architecture

```text
Android app / Next.js web
          |
        HTTPS
          |
  Cloud Run API (one warm instance initially)
      |        |             |
 Cloud SQL  Secret Manager   Private Cloudflare R2
 PostgreSQL     |             documents/photos
      |         |
 backups/PITR  Razorpay + Firebase/FCM + Google Identity
```

Recommended first production configuration:

- Cloud Run in `asia-south1`, minimum instances `1`, maximum instances `1` initially.
- Cloud SQL PostgreSQL 16 in the same region with automated backups, point-in-time recovery, and deletion protection.
- Artifact Registry images tagged with the Git commit SHA.
- Secret Manager with least-privilege access for the Cloud Run runtime service account.
- Existing private R2 integration for KYC, identity documents, profile photos, and PG photos.
- Vercel for the Next.js application, with its exact origin in `CORS_ALLOWED_ORIGINS`.
- Play Console Internal Testing before closed/open testing or production.

Detailed commands and the current GCP migration sequence are in [docs/deployment.md](docs/deployment.md) and [docs/WORKING_TECH_STACK_AND_DEPLOYMENT.md](docs/WORKING_TECH_STACK_AND_DEPLOYMENT.md).

### Pilot deployment on Render

The root [render.yaml](render.yaml) provisions the Docker backend and PostgreSQL:

1. Push the repository to a private or appropriately controlled Git provider.
2. Create a Render Blueprint from `render.yaml`.
3. Keep the API and database in the same region.
4. Set `CORS_ALLOWED_ORIGINS` to the exact deployed web origin(s), without trailing slashes.
5. Set the active `GOOGLE_OAUTH_CLIENT_ID`.
6. Add private `S3_ACCESS_KEY` and `S3_SECRET_KEY` values.
7. Add Razorpay/Firebase variables only when those integrations are ready.
8. Deploy and verify `/actuator/health` and `/api/v1/health`.
9. Confirm Flyway completed successfully before accepting traffic.

Free services and expiring databases are not suitable for valuable customer, KYC, booking, or payment data. Use a paid database and external backups before a real launch.

### Self-hosted deployment

`infra/docker-compose.prod.yml` runs PostgreSQL, the backend, and Caddy on one VM. Caddy provides HTTPS and trustworthy forwarded client IPs.

```bash
cp infra/.env.example infra/.env
cp infra/Caddyfile.example infra/Caddyfile
# Fill every production variable and replace the example domain.
docker compose -f infra/docker-compose.prod.yml up -d --build
```

Deploy the Next.js application separately and point `NEXT_PUBLIC_API_BASE_URL` to the public HTTPS API. Back up the database before each high-risk migration.

### Android release

The permanent Android application ID is `com.hipg.app`. The current Flutter toolchain resolves `compileSdk`/`targetSdk` to Android API 36; confirm the generated AAB still targets the Play-required API level whenever Flutter is upgraded.

1. Create and securely back up a dedicated upload keystore.
2. Copy `mobile/android/key.properties.example` to the ignored `mobile/android/key.properties` and fill it, or provide the documented CI variables.
3. Register the release SHA-1/SHA-256 in Firebase and Google Cloud.
4. Restrict Maps/OAuth configuration to `com.hipg.app` plus the correct signing certificate fingerprints.
5. Build the release bundle:

```powershell
Set-Location mobile
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://api.example.com/api/v1 `
  --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

6. Upload the AAB to Play Console Internal Testing.
7. Test upgrade/install, OTP, Google login, maps, location denial, uploads, booking, Razorpay, direct payment, receipts, notifications, and account/session expiry on real devices.
8. Increase the `version:` build number in `mobile/pubspec.yaml` (for example `0.1.0+2`) before every later Play upload; Play rejects a reused version code.

After the configured backend is deployed, use these public, login-free pages in Play Console (replace the host only if the API host changes):

- Privacy policy: `https://hipg-website.pages.dev/privacy/`
- Terms: `https://hipg-website.pages.dev/terms/`
- Account deletion: `https://hipg-website.pages.dev/account-deletion/`

## Access and account setup

Use separate staging and production projects/accounts. Grant access to named individuals, enable MFA, and avoid shared credentials.

| System | Required access | Recommended control |
|---|---|---|
| Git repository | Developers and release automation | Protected branches, reviewed pull requests, secret scanning |
| GCP/Render | Deployment operators | Least-privilege IAM; no owner/admin role for routine deploys |
| PostgreSQL | Backend runtime and limited operators | Private networking, unique credentials, audited emergency access |
| Secret Manager | Backend runtime and release admins | Runtime reads only required secrets; humans do not copy secrets into docs |
| Cloudflare R2/S3 | Backend runtime | Bucket private, scoped API token, no public listing/read access |
| Firebase | Mobile/release and runtime service accounts | Package/SHA restrictions, separate human and service access |
| Google Maps/OAuth | Release admins | API restrictions, package name and signing SHA restrictions |
| Razorpay | Finance/operations | MFA, least privilege, separate test/live keys, webhook secret rotation |
| Play Console | Release and compliance owners | Role-specific access; production release approval restricted |
| Vercel | Web deployers | Team roles, protected production variables |

### Admin accounts

The application deliberately has no public admin registration. Provision admin users through an approved operational process and record who authorized the access. Never add admin passwords, OTPs, reviewer credentials, or private test accounts to Git or this README.

### Play Console “App access” declaration

Because important screens require login, Google Play reviewers need working review instructions:

- Explain how to reach customer, owner, and, if reviewed, admin-gated functionality.
- Provide a dedicated non-production reviewer account/phone flow in **Play Console → Policy and programs → App content → App access**.
- If OTP is required, provide a stable review mechanism approved for the staging environment; do not ask reviewers to contact a developer manually.
- Ensure the reviewer environment contains safe sample PGs, rooms, beds, bookings, and test-mode payment data.
- Keep reviewer credentials in Play Console, not in the repository, screenshots, release notes, or public privacy policy.
- Confirm the account does not expose real customer documents, payments, or personal data.

## Privacy, permissions, and Play Store declarations

### Current Android permissions

| Permission | Why it is used | User control |
|---|---|---|
| Internet | API, authentication, maps, payments, uploads, and live updates | Required for connected features |
| Notifications (`POST_NOTIFICATIONS`) | Booking, payment, complaint, support, and account updates | Runtime permission on Android 13+; denial must not block core browsing |
| Approximate location | Nearby PG search | Requested only when the user chooses nearby discovery |
| Precise location | More accurate nearby results | Optional; manual city/area search remains available |

The manifest does not request broad storage, contacts, call-log, SMS-reading, microphone, or background-location access. File selection uses the system picker. External HTTPS, map, geo, and UPI apps may be opened only after a user action.

### Data handled by the platform

Depending on the role and feature used, Hi PG may process:

- Account data: name, email, verified mobile number, role, login/session identifiers.
- Customer profile data: occupation, address, guardian/contact details, profile photo, and consent versions.
- Identity/KYC data: chosen document type, limited structured identifiers such as last four characters, uploaded identity/KYC documents, and review status.
- Property data: owner details, PG address/location, coordinates, photos, facilities, floors, rooms, beds, and prices.
- Booking/stay data: selected bed, dates, status, notices, complaints, and support requests.
- Financial records: quoted amounts, fees, deposits, receipts, Razorpay identifiers/status, direct-payment references, and owner decisions.
- Device/technical data: push token, IP/rate-limit information, logs, request IDs, and error/diagnostic information.
- Location: foreground coordinates when the customer explicitly uses nearby discovery.

Raw card, bank, or UPI PIN credentials must never be collected or stored by Hi PG. Razorpay handles gateway payment credentials. Full Aadhaar numbers are not accepted as structured profile fields; Aadhaar must remain optional, alternatives must be available, separate consent is required, and any uploaded document must stay private.

### Data sharing and service providers

The production privacy policy and Play Data safety form must accurately describe the providers actually enabled for the release, which may include:

- Hosting/database provider (for API and PostgreSQL data).
- Cloudflare R2 or another S3-compatible provider (private documents/photos).
- Firebase/Google Identity (phone authentication, Google Sign-In, push messaging).
- Google Maps Platform (maps and location-based discovery).
- Razorpay (payments, refunds, subscriptions, and owner settlements).
- Transactional SMS/email provider, if enabled.
- Monitoring/error-reporting provider, if added.

Do not declare a provider merely because code support exists; declare what the production build actually sends. Revisit the disclosure whenever a provider or data flow changes.

### Privacy policy requirements

Before public testing or production, publish a lawyer-reviewed Privacy Policy on a stable public HTTPS page that does not require login. Add that URL in Play Console and inside the app. The policy should state:

1. Legal entity/operator name, postal address, support email, and grievance/privacy contact.
2. Effective date, version, and how material changes are communicated.
3. Data categories collected for customers, owners, and admins.
4. Purpose and lawful/consent basis for authentication, booking, payments, KYC, location, notifications, support, fraud prevention, and legal compliance.
5. Which data is required versus optional, including manual search when location is denied.
6. Service providers and categories of recipients.
7. Storage locations, international transfers where applicable, and security safeguards.
8. Retention periods for accounts, KYC/identity documents, bookings, invoices, payment records, logs, complaints, and support tickets.
9. Account deletion, correction, consent withdrawal, and complaint/grievance procedures.
10. Treatment of Aadhaar and alternative identity documents, including voluntary consent and limited use.
11. Payment boundaries: Razorpay-verified payments versus owner-confirmed direct payments.
12. Children/minor eligibility and age restrictions appropriate to the intended market.
13. Cookies/web analytics, if any are later added to the Next.js site.

> This README documents engineering behavior; it is not a substitute for a jurisdiction-specific Privacy Policy, Terms of Service, cancellation/refund policy, grievance policy, or professional legal advice.

### Play Data safety preparation

Before completing the Play Console Data safety form, verify the production APK/AAB and backend traffic. At minimum review declarations for:

- Personal information and user IDs.
- Phone number and email address.
- Approximate and precise location.
- Photos/files and identity/KYC documents.
- Financial/payment and purchase history.
- App interactions, diagnostics, and device/push identifiers.
- Whether each category is collected, shared, optional, encrypted in transit, and deletable.

The form, privacy policy, runtime permission prompts, backend behavior, and in-app consent wording must agree exactly.

### Account and data deletion

The customer/owner Account tab now exposes permanent deletion and the backend serves web-accessible instructions at `/account-deletion`. The implemented workflow:

- authenticates the requester and password-rechecks email/password accounts;
- prevents cross-account and consumer-flow ADMIN deletion;
- revokes sessions and notification tokens;
- stops active AutoPay and unpublishes owner properties;
- deletes or anonymizes eligible profile/support data;
- removes private objects through a durable retry queue;
- retains only anonymized records needed for tax, fraud, payment, dispute, consent, or legal obligations;
- records a minimal non-PII deletion audit.

## Security and operations

- All production traffic must use HTTPS.
- Keep CORS restricted to exact trusted web origins.
- Keep R2/S3 buckets private; clients receive only short-lived signed URLs.
- Never log passwords, OTPs, JWTs, refresh tokens, secrets, full identity documents, signed URLs, or complete sensitive payment payloads.
- Rotate secrets through the hosting secret manager, not through source changes.
- Back up PostgreSQL daily, enable point-in-time recovery, and perform restore drills.
- Monitor health, error/latency rates, database capacity, Flyway failures, auth throttling, booking conflicts, payment/webhook failures, document access, notification delivery, and unresolved support tickets.
- Retain prior commit-SHA container images for application rollback.
- Treat Flyway migrations as forward-only; take a backup before high-risk schema changes.
- Use one API instance until scheduled work and live events are externalized.

See [docs/security.md](docs/security.md) for the implemented authorization, token, rate-limit, CORS, document, and logging controls.

## Known production-readiness gaps

The repository is feature-rich but the following must be completed or verified for the intended production environment:

- Publish approved Privacy Policy, Terms, cancellation/refund rules, Aadhaar/identity consent, and grievance details.
- Obtain legal approval for the implemented `2026-10-02` retention/deletion policy and required financial-record periods.
- Use paid PostgreSQL infrastructure with backups, PITR, deletion protection, and a tested restore procedure.
- Complete release signing and Play Console Internal Testing.
- Restrict Firebase, OAuth, and Maps configuration to the production package and signing keys.
- Verify Firebase Phone Authentication, FCM token registration/delivery, and any SMS/email provider on real devices.
- Complete Razorpay live-account, webhook, Route settlement, subscription, refund, and reconciliation verification.
- Define operational handling for direct-owner payment disputes and refunds.
- Add production monitoring, alerts, incident response, and support procedures.
- Decide how scheduled jobs and live events scale before enabling multiple API instances.
- Complete authorization, payment, concurrency, migration, backup/restore, and end-to-end release testing.
- Add iOS configuration only if iPhone support is part of the launch scope.

## Release checklist

### Product and testing

- [ ] Customer, owner, and admin journeys pass in staging.
- [ ] Monthly/day-wise pricing and date overlap rules are verified.
- [ ] Booking/payment concurrency and idempotency tests pass.
- [ ] Complaints and platform support remain separate workflows.
- [ ] Location denial leaves manual discovery usable.

### Privacy and security

- [ ] Public Privacy Policy and Terms URLs are live and linked in the app/store.
- [ ] Play Data safety declarations match real production behavior.
- [ ] App-access reviewer instructions work without developer assistance.
- [ ] Account/data deletion process is published and tested.
- [ ] No secret or real customer data is committed or bundled.
- [ ] Role and ownership authorization is tested server-side.
- [ ] Private storage and signed access are verified.
- [ ] CORS, OAuth, Maps, Firebase, and signing restrictions are exact.

### Infrastructure

- [ ] Production database backups, PITR, deletion protection, and restore drill are complete.
- [ ] Secret access is least-privilege.
- [ ] Health checks, logs, dashboards, and alerts are enabled.
- [ ] Flyway migration is reviewed and a pre-deploy backup exists.
- [ ] Cloud Run instance strategy matches the scheduler/SSE design.

### Payments and mobile release

- [ ] Razorpay live keys exist only in the secret manager.
- [ ] Webhook signature, refund, idempotency, and settlement tests pass.
- [ ] Direct-owner approval/rejection and dispute procedures are tested.
- [ ] Release keystore is backed up securely.
- [ ] Release SHA fingerprints are registered with Google/Firebase.
- [ ] AAB is installed through Play Internal Testing and tested on real devices.

### Deployment

- [ ] All automated tests, lint, analysis, build, and dependency audit checks pass.
- [ ] Staging smoke test passes.
- [ ] Production deployment is explicitly approved.
- [ ] Post-deploy health, login, booking, payment, upload, and notification smoke tests pass.
- [ ] Monitoring is watched during the release window.

## Documentation

- [Architecture](docs/architecture.md)
- [API contract](docs/api.md)
- [Database model](docs/database.md)
- [Security controls](docs/security.md)
- [Deployment guide](docs/deployment.md)
- [Google Play release worksheet](docs/play-console-release.md)
- [Full technology and production deployment guide](docs/WORKING_TECH_STACK_AND_DEPLOYMENT.md)
- [Direct-owner payment and profile rules](docs/direct-owner-payment-and-profile.md)
- [Architecture decisions](docs/decisions.md)
- [Requirements](docs/requirements.md)
- [Development workflow](docs/development-workflow.md)

For repository contribution and shared-file rules, see [CLAUDE.md](CLAUDE.md). Do not add credentials, legal identity documents, real payment data, or production secrets to documentation, source control, screenshots, or issue trackers.
