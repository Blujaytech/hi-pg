# Google Play release worksheet

Use this worksheet for the current `com.hipg.app` release. Confirm every answer against the deployed production build before submitting; Google Play declarations describe actual runtime behavior, not only source code.

## Store listing

- App name: **Hi PG**
- Recommended category: **House & Home**
- Short description: **Find, book and manage PG stays with payments and live availability.**
- Support email: use the same monitored address as `LEGAL_SUPPORT_EMAIL`.
- Website: `https://hipg-website.pages.dev/` until a custom Hi PG domain is attached.
- Privacy policy: `https://hipg-website.pages.dev/privacy/`

Suggested full description:

> Hi PG helps customers discover and book paying-guest accommodation and helps PG owners manage properties from one app.
>
> Customers can search by city or nearby location, view live room and bed availability, compare monthly and day-wise stays, complete a secure profile, book a specific bed, pay through supported payment options, view receipts, manage stays, and contact support.
>
> PG owners can manage properties, floors, rooms, beds, pricing and availability; review booking and direct-payment requests; manage customers, fees, deposits, complaints and receipts; and complete property verification.
>
> Location is optional and is used only when a customer chooses nearby search. Manual city search remains available. Payment credentials such as card details, bank passwords and UPI PINs are handled by the payment provider and are not stored by Hi PG.

Do not claim features that are disabled in the release environment.

## App content answers

### Privacy policy and account deletion

- Privacy URL: `https://hipg-website.pages.dev/privacy/`
- External account-deletion URL: `https://hipg-website.pages.dev/account-deletion/`
- In-app path for both customers and owners: **Account → Delete account**
- Terms URL: `https://hipg-website.pages.dev/terms/`

Set every value in `legal-site/.env` from its `.env.example`, build, and deploy the static site to the existing `hipg-website` Cloudflare Pages project. Open each URL in a signed-out/private browser and verify that it returns HTTPS content without a login.

### App access

Choose that some functionality is restricted. Provide Google reviewers with stable, non-production customer and owner access instructions in Play Console. Include:

1. How to enter the customer flow and complete OTP/Google sign-in.
2. How to enter the owner flow and sign in.
3. Any fixed test OTP or reviewer credentials supported by the review environment.
4. A note that the accounts contain only seeded test properties and payments.

Never put reviewer credentials in Git, this worksheet, the store description, or screenshots.

### Ads, audience and declarations

- Ads: **No** for the current build; it has no advertising SDK or displayed ads.
- Target audience: **18 and over**. Do not select child age groups.
- Government app: **No**.
- Health apps: **My app doesn't provide any health features**.
- Financial features: the current app accepts payment for physical accommodation but does not provide a wallet, money transfer, lending, banking, investment, insurance, or cryptocurrency product. Select **My app doesn't provide any financial features** if the production behavior remains this way. Reassess if a wallet, stored balance, lending, or transfer feature is added.
- Content rating: complete the questionnaire truthfully for marketplace/user-generated property and support content. The current app has no gambling, sexual, violent, drug, or ad content by design.

Razorpay is used for payment for a physical service (accommodation); do not describe rent as a digital in-app product.

## Data safety draft

Review production network traffic and provider contracts before submitting. The current application can collect the following:

| Play data area | Current use | Required/optional |
|---|---|---|
| Name, email, phone, user/account ID | Authentication, profiles, booking and support | Account/profile dependent |
| Address and guardian/contact details | Monthly booking and stay administration | Required only for applicable stays |
| Approximate and precise location | User-triggered nearby-property discovery | Optional; manual search is available |
| Photos and files | Profile/property photos and private identity/KYC verification | Feature/role dependent |
| Purchase/payment history | Booking amount, status, references, receipts, refunds and reconciliation | Required for paid bookings |
| Messages/other user content | Complaints, support requests and owner review notes | Optional/feature dependent |
| Device or other identifiers | Push notification token, session/security and diagnostic identifiers | Notifications optional; security data operational |

Production traffic must use HTTPS. Hi PG does not store raw card data, bank-login credentials, or UPI PINs. Service-provider processing and any Play definition of “sharing” must be answered according to the final Firebase, Google, Razorpay, hosting, storage and notification configuration—not guessed from this table.

Users can request deletion inside the app and from the public deletion page. Profile data and private files are deleted or anonymized; limited anonymized booking, payment, receipt, tax, fraud-prevention and legal-acceptance records may be retained under the published policy.

## Closed test and production access

1. Finish every App content and Store listing item above.
2. Select the intended launch countries/regions; start with India unless the business has approved other regions.
3. Create a closed-testing release using a new version code and the signed AAB.
4. Add testers and share the opt-in link.
5. Keep at least **12 testers opted in continuously for at least 14 days**, matching the requirement shown for this developer account.
6. Collect real feedback and fix crashes, authentication, booking, payment, upload and deletion issues.
7. Answer the production-access questions using the real test results, then apply for access.

Current locally generated bundle: `mobile/build/app/outputs/bundle/release/app-release.aab`.

## Pre-upload checks

- Increment the build number in `mobile/pubspec.yaml` before each upload.
- Confirm API 36 targeting, package `com.hipg.app`, release signing, Firebase SHA fingerprints and restricted Maps/OAuth keys.
- Deploy database migration V28 before testing deletion.
- Verify the three public legal URLs after deployment.
- Test customer and owner deletion on disposable accounts, including active AutoPay cancellation and private-file removal.
- Run backend integration tests in an environment with Docker/Testcontainers or a dedicated PostgreSQL test database.
- Test install/upgrade from the Play closed track on physical Android devices.
