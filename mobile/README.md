# hi pg — mobile

Flutter app for both roles (PG owner and student) from one codebase, gated by
role after sign-in. Architecture lives in `../PG_PLATFORM_TECHNICAL_PLAN.md`
and `../docs/`; UI decisions are ADR-0025 in `../docs/decisions.md`.

## Run

```sh
flutter run            # Uses https://pg-platform-api.onrender.com/api/v1
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1 # local Docker backend
flutter run --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Add `GOOGLE_MAPS_API_KEY=...` to the uncommitted
`android/local.properties` before an Android build. CI may provide the same
name as an environment variable. The key must be restricted to Android app
`com.example.mobile` and every SHA-1 certificate used to sign an APK.

## Layout

| Folder | What lives there |
| --- | --- |
| `lib/core` | env config, secure storage, design tokens and theme (`theme.dart`) |
| `lib/shared` | API client, bottom-tab shell, account screen, shared UI states and widgets, brand kit |
| `lib/auth` | launch animation (`splash_screen.dart`), welcome, owner email sign-in, student OTP + Google sign-in |
| `lib/owner`, `lib/student` | one folder per feature: screen + models + repository |

## Design system

Monochrome: build screens from `AppColors` / `AppTheme` and the shared pieces in
`lib/shared/app_states.dart` (`StatusPill`, `IconTile`, `SectionHeader`,
`FormSheet`, loading/empty/error views) instead of raw colours. Green, amber and
red are reserved for state (available/paid, pending, overdue/destructive).

## Brand assets

The launcher icons (adaptive, themed and legacy) and the native splash are
generated from `HiPgMarkPainter` in `lib/shared/brand/hi_pg_brand.dart`. After
changing the mark, regenerate them instead of editing the PNGs:

```sh
flutter test tool/brand_assets_test.dart
```

## Tests

```sh
flutter test
```
