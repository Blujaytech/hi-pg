# hi pg — mobile

Flutter app for both roles (PG owner and student) from one codebase, gated by
role after sign-in. Architecture lives in `../PG_PLATFORM_TECHNICAL_PLAN.md`
and `../docs/`; UI decisions are ADR-0025 in `../docs/decisions.md`.

## Run

```sh
flutter run            # Uses the production Cloud Run API
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1 # local Docker backend
flutter run --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
flutter run --dart-define=LEGAL_BASE_URL=https://legal.example.com
```

`LEGAL_BASE_URL` defaults to the public Cloudflare Pages legal site. Override it
for staging or a future custom domain. The Account tab links to `/privacy`,
`/terms`, and `/account-deletion` and exposes authenticated customer/owner
account deletion.

Add `GOOGLE_MAPS_API_KEY=...` to the uncommitted
`android/local.properties` before an Android build. CI may provide the same
name as an environment variable. The key must be restricted to Android app
`com.hipg.app` and every SHA-1 certificate used to sign an APK.

Student login, invited-owner claiming, and owner-profile phone verification all
use Firebase Phone Authentication. The app exchanges the verified Firebase ID
token for a Hi PG backend session or profile update; publishing through Play
Store is not required for OTP delivery. Owner invitation messages are separate
business SMS sent by the configured backend provider.

FCM notifications use separate Android channels for important account activity
and optional stay ideas. The backend engagement scheduler targets only active
customers with a registered device and no active booking, caps discovery
messages at one per day and three per week, and opens Explore when tapped.

## Layout

| Folder | What lives there |
| --- | --- |
| `lib/core` | env config, secure storage, design tokens and theme (`theme.dart`) |
| `lib/shared` | API client, bottom-tab shell, account screen, shared UI states and widgets, brand kit |
| `lib/auth` | launch animation (`splash_screen.dart`), welcome, owner email sign-in, student OTP + Google sign-in |
| `lib/notification` | persistent inbox models/repository/screen and FCM notification-tap routing |
| `lib/owner`, `lib/student` | one folder per feature: screen + models + repository |

## Design system

Neutral-first: build screens from `AppColors` / `AppTheme` and the shared pieces
in `lib/shared/app_states.dart` (`PremiumAppBar`, `StatusPill`, `IconTile`,
`SectionHeader`, `FormSheet`, loading/empty/error views) instead of raw colours.
Hi PG rose marks brand actions and selected navigation; green, amber and red are
reserved for state (available/paid, pending, overdue/destructive).

## Brand assets

In-app surfaces use the plain grey-and-rose `HiPgPlainLogo`; the full-colour
launcher icon remains separate. The Android native splash is generated from
`assets/branding/hi_pg_logo_plain.png` so no launcher tile flashes before the
cinematic Flutter splash. Regenerate assets instead of editing PNGs:

```powershell
powershell -ExecutionPolicy Bypass -File tool/generate_brand_assets.ps1
```

## Tests

```sh
flutter test
c```
