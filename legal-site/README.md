# Hi PG public website

The public Hi PG product, download, legal and support website deployed on Cloudflare Pages.

## What is hosted where

- **Cloudflare Pages:** landing page, product information, support links and legal documents.
- **Cloudflare R2:** signed Android APK. The APK is larger than the Cloudflare Pages 25 MiB per-file limit.
- **Google Cloud:** application API and PostgreSQL database; no credentials are placed in this website.

Existing public routes remain stable:

- `/privacy/`
- `/terms/`
- `/account-deletion/`
- `/refund-cancellation/`
- `/contact/`

## Configuration

Copy `.env.example` to `.env` and replace every value with verified production information. `.env` is ignored and must never be committed.

The application download settings must describe the exact R2 object being published:

```env
APP_DOWNLOAD_URL=https://downloads.example.com/releases/hi-pg-android-0.1.1-build-2.apk
APP_VERSION=0.1.1 (build 2)
APP_APK_SIZE=59.6 MB
APP_APK_SHA256=64-character-sha256-checksum
APP_MIN_ANDROID=Android 7.0+
```

Use a versioned APK object instead of overwriting the old object. That ensures the displayed checksum and cache headers always match the file.

## Build and preview

```powershell
Set-Location legal-site
npm run build
npx wrangler pages dev dist
```

The build fails if required public/legal settings are absent, either public URL is not HTTPS, or the APK checksum is malformed.

## Publish a new APK

Build the signed universal release APK with the intended API, legal and Google OAuth configuration:

```powershell
Set-Location mobile
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.example.com/api/v1 `
  --dart-define=LEGAL_BASE_URL=https://hipg-website.pages.dev `
  --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=your-web-client-id
```

Verify and calculate its checksum:

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

Upload the APK to R2:

```powershell
Set-Location ..\legal-site
npx wrangler r2 object put `
  "hi-pg-downloads/releases/hi-pg-android-VERSION-build-CODE.apk" `
  --remote `
  --file "..\mobile\build\app\outputs\flutter-apk\app-release.apk" `
  --content-type "application/vnd.android.package-archive" `
  --content-disposition "attachment; filename=`"hi-pg-android-VERSION.apk`"" `
  --cache-control "public, max-age=31536000, immutable"
```

Update the five `APP_*` values in `.env`, rebuild, and deploy the site.

## Deploy the website

```powershell
Set-Location legal-site
npm run build
npx wrangler pages deploy dist --project-name hipg-website --branch main
```

For production APK delivery, connect a custom hostname such as `downloads.yourdomain.com` to the `hi-pg-downloads` R2 bucket and use that URL for `APP_DOWNLOAD_URL`. The public `r2.dev` URL is suitable only until the custom hostname is available.

## Android and Play Console links

Use these stable HTTPS pages:

- Privacy policy: `https://hipg-website.pages.dev/privacy/`
- Account deletion: `https://hipg-website.pages.dev/account-deletion/`
- Terms: `https://hipg-website.pages.dev/terms/`

The mobile application uses the same origin through `LEGAL_BASE_URL`.
