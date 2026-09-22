# Direct owner payment and customer profile specification

Status: the core profile-gating, payment-choice, direct-UPI claim, and owner-review flow is implemented in the backend and Flutter app. Sections covering production push/SMS delivery, payment-destination validation, disputes, and direct-payment refunds remain launch controls or follow-up work; they are not represented as completed features.

Last legal-source review: 22 September 2026. This is a product and engineering specification, not a substitute for advice from counsel in every state or city where a PG operates.

## 1. Outcomes and non-negotiable rules

The booking payment sheet offers two choices:

1. **Pay Online** — pay securely using UPI, card, or net banking through Razorpay.
2. **Pay Directly to Owner** — pay the exact quoted amount to the verified PG owner's UPI destination and ask the owner to confirm receipt.

The following rules apply:

- Razorpay remains the recommended and default path because the backend can verify a captured payment and reconcile refunds and Route transfers.
- A customer's **I Have Paid** action is a payment claim, not proof of payment. It must never allocate a bed by itself.
- A direct payment is confirmed only when an authorised owner enters and confirms the exact amount actually received.
- Bed allocation happens in the same database transaction as owner approval, after rechecking the booking, hold, amount, and bed availability.
- Direct payment must be disabled by default for every PG and enabled only after owner, property, payment-destination, policy, and notification prerequisites pass.
- The platform must not describe a manually confirmed direct transfer as gateway-verified, protected by Razorpay, held in escrow, or automatically refundable.
- Full Aadhaar numbers must not be collected. Aadhaar is voluntary, alternatives are always available, and only the last four characters may be retained as structured data after a compliant verification flow.
- DAY_WISE and MONTHLY bookings have different profile requirements. A customer who is eligible for DAY_WISE must not be forced to complete the additional MONTHLY fields.
- The exact price, cancellation policy, deposit policy, notice period, and accepted terms are immutable snapshots on each booking.
- No feature may state or imply that unpaid PG dues automatically affect CIBIL or another formal credit score.

## 2. Terminology

- **Customer** means the existing student-side authenticated user and linked `Student` record.
- **Expected amount** means the immutable total shown and accepted before payment, stored in paise.
- **Payment claim** means the customer's statement that a direct transfer was completed, including the reference and supporting details.
- **Owner approval** means the owner's confirmation that funds matching the expected amount reached the configured destination.
- **Payment destination** means the owner name and UPI VPA used for a direct transfer. A snapshot is attached to each request so later owner changes cannot rewrite history.
- **Direct payment request** is the auditable record joining a booking hold, pricing snapshot, destination snapshot, customer claim, owner decision, and any refund/dispute record.

## 3. Customer profile and booking eligibility

Customers may browse, search, inspect prices, and save PGs before completing a profile. Profile eligibility is checked when they start a booking. Existing customers must always retain access to their bookings, receipts, cancellation, support, and data-rights screens even if a new profile requirement is introduced later.

### 3.1 Field matrix

| Field | DAY_WISE | MONTHLY | Product rule |
|---|---|---|---|
| Authenticated customer account | Required | Required | Use the authenticated principal; never accept a customer id from the client. |
| Legal full name | Required | Required | Explain that it must match the selected identity document. |
| OTP-verified mobile | Required | Required | A manually entered but unverified number is not eligible. |
| Adult status | Required | Required | Initial release should be 18+ only. Supporting minors requires a separate guardian identity, relationship, consent, and agreement flow. |
| Full date of birth | Optional unless law/property check-in policy requires it | Required only if needed for agreement or identity matching | Do not collect it merely to calculate age if an adult-status assertion is enough. |
| Profession/occupation | Required | Required | Used as a contact/profile field only. Do not use it for discriminatory filtering. |
| Current/permanent address | Not required by platform default | Required | DAY_WISE may require it only when a documented state/city lodging rule applies. Display that requirement before checkout. |
| Emergency contact | Optional | Required before check-in | Store separately from login mobile and disclose its emergency-only purpose. |
| Identity verification | Property/jurisdiction configurable; never Aadhaar-only | Required using one supported choice | Alternatives include passport, driving licence, voter ID, or another locally accepted document. |
| Aadhaar | Optional and never the only choice | Optional and never the only choice | Available only after the platform is approved and integrated as an OVSE. Never accept a full-number text field. |
| Booking terms | Required | Required | Versioned, unchecked acceptance. |
| Monthly occupancy/notice/deposit terms | Not applicable | Required | Snapshot the accepted version on the booking. |

The eligibility API should return machine-readable missing requirements rather than one generic failure, for example:

```json
{
  "eligible": false,
  "bookingType": "MONTHLY",
  "missing": ["CURRENT_ADDRESS", "IDENTITY_VERIFICATION", "MONTHLY_TERMS"]
}
```

Profile edits after a booking request do not mutate that request's legal-name, address, identity-verification, price, or policy snapshots. A material mismatch discovered before approval moves the request to review; it is not silently overwritten.

### 3.2 Customer-visible consent controls

Use separate, unchecked controls. Do not combine all permissions into one checkbox and do not bundle marketing consent.

Required booking acceptance:

> I accept the Booking Agreement, cancellation and refund policy, house rules, and the price shown for this booking.

Required privacy acknowledgement/consent where consent is the processing basis:

> I have read the Privacy Notice. I understand which profile and booking information will be used to process this booking, shared with the selected PG owner, and retained as described.

Additional MONTHLY acceptance:

> I accept the monthly rent, security deposit, notice period, due-date, move-out, and itemised deduction terms shown above.

Conditional Aadhaar consent, shown only when the customer voluntarily selects that option:

> I voluntarily choose Aadhaar offline verification for identity verification. I understand the data requested, its stated purpose, the available non-Aadhaar alternatives, who may receive the verification result, and how to withdraw consent where applicable.

Direct payment acknowledgement:

> I understand that this payment goes directly to the PG owner, is not collected or verified by Razorpay or held by the platform, and my bed is allocated only after the owner confirms the exact amount received.

Persist the terms/notice version, language, timestamp, authenticated user, booking id, and affirmative action. Consent does not authorise a use that is prohibited by another law.

## 4. Aadhaar and identity-verification design

### 4.1 Production rule

Until the platform has completed UIDAI OVSE registration and the approved technical integration, keep `CUSTOMER_AADHAAR_VERIFICATION_ENABLED=false`. Show alternative identity methods instead. A typed Aadhaar number, uploaded card photograph, or unchecked photocopy is not a substitute for compliant verification.

When enabled:

1. Present Aadhaar as one voluntary option alongside viable alternatives.
2. Show the purpose, requested attributes, recipients, retention, withdrawal route, and OVSE identity before asking for consent.
3. Use UIDAI Paperless Offline e-KYC or an Aadhaar App Verifiable Credential and validate the UIDAI digital signature.
4. Extract only the attributes approved for the displayed purpose.
5. Delete the raw XML/credential, share code, QR payload, temporary files, and parsing logs immediately after the transaction succeeds or fails.
6. Persist only verification status, method, timestamp, consent record/version, provider transaction reference, and Aadhaar last four if necessary.
7. Never use Aadhaar last four as a unique identifier, deduplication key, login factor, or search field exposed to owners.
8. Never expose full or raw Aadhaar data to PG owners, support exports, analytics, crash reporting, logs, notifications, or public URLs.
9. An owner normally sees only `Identity verified`, legal name, and the minimum booking-type-specific data. Aadhaar last four should be hidden unless counsel establishes a specific need.
10. Provide a non-Aadhaar path with equivalent booking access. Refusal of Aadhaar cannot itself be the rejection reason.

UIDAI states that offline verification cannot be performed on behalf of another entity. The platform must define and obtain approval for its own verification purpose; it must not offer itself as an unapproved Aadhaar-verification proxy for independent PG owners.

### 4.2 Non-Aadhaar documents

- Maintain a jurisdiction-aware allow-list rather than accepting any arbitrary file as proof.
- Store document type and a masked identifier; do not place full document numbers in ordinary logs or notifications.
- Keep document objects private, malware-scan uploads, validate actual file content rather than trusting the filename/MIME header, and issue short-lived signed URLs only after an ownership check.
- Record every admin/owner view in an auditable event.
- Do not expose one customer's document or address to another customer.

## 5. Owner direct-payment settings and verification

Direct payment is configured per PG, not globally for every property owned by the same account.

Suggested settings:

```text
allowDirectOwnerPayment
directPaymentWindowMinutes          default 15, allowed 10..30
dayWiseOwnerReviewMinutes           default 30, allowed 15..60
monthlyOwnerReviewMinutes           default 120, allowed 30..360
directPaymentAvailabilitySchedule   owner response hours and timezone
paymentDestinationId
```

### 5.1 Enablement prerequisites

All must be true:

- owner account is active;
- owner mobile is OTP-verified;
- owner and PG KYC are approved;
- property is active and permitted for the selected booking mode;
- cancellation, no-show, refund, deposit, and grievance policies are published;
- UPI destination ownership/name has been verified through an approved PSP/provider validation flow;
- the verified owner/beneficiary name is consistent with onboarding records, or an approved exception is documented;
- owner has accepted the direct-payment reconciliation, refund, receipt, tax, and response-SLA obligations;
- real production push and/or transactional notification delivery is working;
- no unresolved suspension, excessive non-response, fraud, or refund backlog exists.

Suggested destination lifecycle:

```text
DRAFT -> PENDING_VERIFICATION -> VERIFIED -> SUSPENDED -> VERIFIED
                              \-> REJECTED
```

Syntax validation or an admin looking at a typed VPA does not prove ownership. Do not display a `Verified` badge unless an approved validation source actually confirmed it. Store validation provider, transaction/reference id, verified beneficiary name, time, and reviewer where applicable.

Changing the owner name, VPA, or mobile creates a new destination version. Existing direct-payment requests retain their immutable destination snapshot. A previous destination cannot be deleted while accounting, refund, or dispute records reference it; it may only be deactivated for future requests.

Customer display:

```text
PG Owner Payment Details

Owner Name: Rahul Kumar
UPI ID: rahul123@upi
Mobile: 98XXXXXX21
Amount: INR 8,500.00
Booking reference: BKG-2026-001234

[ Copy UPI ID ]
[ Pay via UPI ]
```

The UPI deep link must prefill the immutable amount, INR currency, verified VPA, owner name, and booking reference. The app must repeat the VPA and amount on return because an external UPI application's completion screen is not available as reliable server evidence.

## 6. Price authority and exact-amount approval

The owner configures room/bed pricing before a booking. Checkout creates a server-side price snapshot containing, as applicable:

- booking type and dates;
- quantity of nights or monthly period;
- base accommodation amount;
- taxes with responsible supplier;
- security deposit;
- separately described utilities or one-time charges;
- discounts or approved adjustments;
- platform/service fee, if any;
- owner-payable direct amount;
- total payable and currency;
- policy versions.

Money is stored as integer paise, never floating point. The client cannot submit the authoritative amount.

During approval, the owner sees expected amount, customer-claimed amount, and destination. The owner must enter the amount actually received. Approval is allowed only when:

```text
actualReceivedAmountPaise == expectedOwnerAmountPaise
```

- Underpayment stays pending/rejected and does not allocate the bed. If partial payments are introduced later, they need a separate ledger and remaining-balance flow; do not overload approval.
- Overpayment does not silently increase the booking price. The owner records and refunds the excess, or a new quote is accepted by the customer before any reallocation.
- An owner cannot change the agreed bed price inside the approval modal. Discounts, waivers, or corrections create a versioned revised quote that the customer accepts before paying.
- A direct transfer bypasses automatic Razorpay Route commission. Before launch, the business must choose either a revenue model that permits this, or a separately disclosed platform fee collected through Razorpay. The platform must not record commission as collected when it never controlled the money.

## 7. Customer checkout experience

### 7.1 Payment choice sheet

```text
Choose how to pay

Pay Online
Pay securely using UPI, Card, or Net Banking

Pay Directly to Owner
Pay the exact amount to the verified PG owner's UPI and ask them to confirm it
```

Show **Pay Directly to Owner** only when all enablement prerequisites are true and the owner is inside the displayed response schedule. Otherwise, show Razorpay without suggesting that direct payment is available.

### 7.2 Direct payment screen

The screen shows:

- countdown for completing the transfer and sending the claim;
- exact price breakdown and total;
- immutable owner/destination details;
- warning to verify the VPA and amount in the external UPI app;
- copy VPA and UPI deep-link actions;
- cancellation/refund warning;
- support link;
- final action: **I Have Paid - Inform Owner**.

Selecting the final action opens a confirmation form:

- expected amount: read-only;
- amount customer says was paid: prefilled, required;
- UPI/bank transaction reference: required, normalised, reasonable length validation but no assumption that every PSP uses the same format;
- payer display name/VPA last characters: optional;
- payment time: required, default current time;
- proof screenshot: optional, clearly labelled as supporting evidence rather than proof;
- direct-payment acknowledgement: required.

The result says `Approval requested`, never `Payment successful` or `Bed booked`.

## 8. Direct-payment state machine

Keep direct-payment state separate from booking state and refund/dispute state.

| Current state | Event | Next state | Booking/inventory effect |
|---|---|---|---|
| `AWAITING_CUSTOMER_PAYMENT` | Customer submits valid payment claim before deadline | `OWNER_REVIEW_PENDING` | Extend the existing bed hold to the owner-review deadline. |
| `AWAITING_CUSTOMER_PAYMENT` | Customer cancels before claiming payment | `CANCELLED` | Cancel/release hold immediately. |
| `AWAITING_CUSTOMER_PAYMENT` | Payment window expires | `EXPIRED` | Expire/release hold; no payment is recorded. |
| `OWNER_REVIEW_PENDING` | Owner confirms exact amount before deadline and bed remains valid | `APPROVED` | Atomically record payment/receipt and confirm booking/bed. |
| `OWNER_REVIEW_PENDING` | Owner rejects with reason | `REJECTED` | No payment is recorded as received; release hold unless a short correction window is explicitly active. |
| `OWNER_REVIEW_PENDING` | Owner-review deadline expires | `EXPIRED` | Never auto-approve. Release hold and start refund/reconciliation handling if the transfer may have arrived. |
| Any non-terminal state | Admin risk suspension | `SUSPENDED` | Prevent approval until reviewed; do not silently reallocate or mark paid. |

Terminal states are immutable. Corrections use append-only events or a new request; they do not rewrite the original decision.

Refund state is independent:

```text
NONE -> REQUIRED -> OWNER_REPORTED_SENT -> CUSTOMER_CONFIRMED
                                      \-> DISPUTED
```

Dispute state is also independent so a previously approved/rejected request retains its accounting history:

```text
NONE -> OPEN -> AWAITING_CUSTOMER|AWAITING_OWNER -> RESOLVED|CLOSED
```

### 8.1 Approval transaction

The server, not the client, performs all of these in one transaction:

1. authenticate owner and check ownership of the PG, booking, room, and bed;
2. pessimistically lock the direct request, booking, and bed;
3. require `OWNER_REVIEW_PENDING` and an unexpired review deadline;
4. re-read the immutable expected amount and require exact match with the entered received amount;
5. ensure the request/reference has not already produced a payment;
6. recheck the date-range exclusion and booking hold;
7. insert the `DIRECT_UPI` payment ledger entry and owner-confirmation audit event;
8. generate a receipt/acknowledgement identifying the PG owner as the direct recipient;
9. move the booking to `CONFIRMED` or `CHECKED_IN` according to its dates;
10. commit, publish availability, and enqueue idempotent notifications.

If the bed can no longer be allocated, approval fails. The owner must not substitute a different bed without the customer's explicit acceptance; any money received becomes refund-required.

Every mutating endpoint requires an idempotency key. A retry returns the original result and cannot insert a second payment or allocate twice.

## 9. Razorpay alternative

The online path continues to use the existing Razorpay implementation:

- create a server-side order for the immutable amount;
- open Checkout for UPI/cards/netbanking;
- treat the client callback as provisional;
- verify the Checkout signature and captured state server-side or process a signed webhook;
- handle duplicate/out-of-order webhooks idempotently;
- confirm the booking only after verified capture;
- create the Route transfer to the PG's verified linked account after commission;
- use gateway refunds and persist refund status/reference.

Online payment does not require owner approval of each booking payment. Both payment methods converge on the same booking, ledger, receipt, notification, and bed-calendar rules, but the evidence sources remain distinct: `RAZORPAY_CAPTURED` versus `OWNER_CONFIRMED_DIRECT_UPI`.

## 10. Cancellation, refund, no-show, and disputes

The exact policy must be visible before payment and snapshotted on the booking. The platform must not use a later policy version against an earlier booking.

| Situation | Required behavior |
|---|---|
| Cancel before either payment method starts | Release hold; no refund record. |
| Direct request cancelled before customer claim | Release hold; state `CANCELLED`. |
| Customer claims direct payment and then wants to cancel | Do not silently cancel. Owner reviews whether funds arrived; if received, apply the accepted cancellation policy and record/refund the resulting amount. |
| Direct request rejected as `NOT_RECEIVED` | Let customer open a dispute with reference/proof; do not mark the booking paid. |
| Direct request expires while funds may have arrived | Booking remains unconfirmed. Mark refund/reconciliation required and notify both parties/support. |
| Bed becomes unavailable after direct funds were sent | Full direct refund is required unless the customer explicitly accepts an equivalent replacement and revised booking. |
| Razorpay capture occurs after an invalid/expired hold | Use the existing automatic gateway refund path; never leave a charge without a bed. |
| Customer cancels after Razorpay capture | Apply snapshotted policy and issue/track gateway refund. |
| Customer cancels after approved direct payment | Owner is the refund sender. Record amount, time, destination, reference, and optional proof; customer may confirm or dispute. |
| Duplicate or excess direct transfer | Do not turn it into extra rent automatically. Record and refund the duplicate/excess. |
| DAY_WISE no-show | Apply the DAY_WISE no-show policy disclosed before payment. |
| MONTHLY cancellation/move-out | Apply the accepted notice, deposit, deduction, and final-settlement rules; deductions must be itemised. |

For a direct payment, the platform acknowledgement must say that the owner reported receiving the amount. It must not be described as bank proof, a Razorpay receipt, or a platform-held tax invoice. Counsel/accounting review must identify whether the owner, platform, or both issue invoices/receipts and how GST and platform fees are represented.

Dispute controls:

- require a reason category and narrative;
- allow private supporting documents from both parties;
- provide a response deadline and escalation path;
- preserve all price, policy, destination, reference, decision, notification, and audit snapshots;
- prevent either party from editing historical evidence;
- permit admin mediation without pretending the platform can independently read a personal UPI account;
- record resolution, refund obligation, and closing reason;
- display consumer grievance contact details and applicable external redress routes.

## 11. False-claim and owner-abuse controls

- A screenshot or transaction reference is evidence supplied by a user, not bank confirmation.
- Do not change a booking to paid on UPI-app return, deep-link callback, screenshot upload, or `I Have Paid` alone.
- Require transaction reference, claimed amount, destination snapshot, and timestamp.
- Detect duplicate references within the same owner/destination and flag cross-account reuse without exposing another customer's data.
- Rate-limit claims, proof uploads, resend-notification actions, and disputes.
- Store device/session/IP security metadata under a documented fraud-prevention purpose and retention period; do not display it to owners.
- Owners must choose a rejection reason such as `NOT_RECEIVED`, `WRONG_AMOUNT`, `WRONG_DESTINATION`, `DUPLICATE_REFERENCE`, or `EXPIRED` and may add a note.
- Repeated customer claims conclusively shown to be false may trigger proportionate restrictions after review and an appeal path, not automatic permanent banning.
- Track owner response time, rejection rate, refund time, unresolved disputes, and customer complaints. Suspend direct payment for abnormal behavior while keeping Razorpay available.
- Prevent owners from approving after the review deadline or after another active booking owns the bed.
- Support/admin cannot manually bypass the date-range exclusion constraint. A support resolution must use the same booking transaction rules.
- Sensitive proof objects must use the private document-storage controls; never attach them directly to push/email notifications.

## 12. Notifications and operational limitation

Required events and recipients:

| Event | Customer | Owner | Admin/support |
|---|---|---|---|
| Direct request created | Amount, destination, countdown | Optional pending-payment signal | No |
| Customer claims paid | Approval pending and deadline | Immediate actionable alert with booking, exact amount, and countdown | Risk rule only |
| Owner has not acted | Reminder before deadline | Escalating reminder | At SLA breach threshold |
| Approved | Booking confirmation and receipt | Ledger/allocation confirmation | No |
| Rejected | Reason and dispute action | Decision record | On dispute/risk rule |
| Expired after claim | Bed not allocated and refund/reconciliation warning | Refund/reconciliation action | Yes if funds may have arrived |
| Refund recorded | Amount/reference and confirm/dispute action | Refund record | No |
| Dispute opened/updated | Status and next action | Status and next action | Work queue |

Use an outbox/idempotency key such as `eventType:requestId:stateVersion` so retries cannot send duplicate messages. In-app state remains authoritative; a missing notification never changes the payment or booking result.

**Current repository limitation:** `LoggingNotificationGateway` logs push/email attempts instead of delivering them; Flutter does not register a real FCM token; authenticated SSE only reaches an app that is currently open. Because owner action is time-sensitive and customer funds may otherwise be stranded, production direct payment must remain feature-flagged off until real push and/or transactional delivery, retries, delivery monitoring, and an operational escalation queue are working.

## 13. Proposed service contracts

These names are proposed. Add their final request/response schemas to `docs/api.md` before or alongside implementation.

Customer:

```text
GET  /student/profile
PUT  /student/profile
GET  /student/profile/booking-eligibility?bookingType=DAY_WISE|MONTHLY&pgId=...

POST /student/bookings/{bookingId}/direct-payment-requests
GET  /student/bookings/{bookingId}/direct-payment-request
POST /student/direct-payment-requests/{requestId}/claim-paid
POST /student/direct-payment-requests/{requestId}/cancel
POST /student/direct-payment-requests/{requestId}/disputes
POST /student/direct-payment-requests/{requestId}/refund-confirmation
```

Owner:

```text
GET   /owner/pgs/{pgId}/direct-payment-settings
PUT   /owner/pgs/{pgId}/direct-payment-settings
POST  /owner/pgs/{pgId}/payment-destinations
POST  /owner/payment-destinations/{id}/verify
GET   /owner/pgs/{pgId}/direct-payment-requests
POST  /owner/direct-payment-requests/{requestId}/approve
POST  /owner/direct-payment-requests/{requestId}/reject
POST  /owner/direct-payment-requests/{requestId}/refunds
```

Admin/support:

```text
GET  /admin/direct-payment/disputes
GET  /admin/direct-payment/requests/{requestId}
POST /admin/direct-payment/requests/{requestId}/suspend
POST /admin/direct-payment/disputes/{disputeId}/resolve
```

Do not return owner payment details from a public unauthenticated endpoint. Return them only to the authenticated customer with an active, owned booking request. Apply the existing ownership-guard pattern and add cross-customer/cross-owner authorization tests.

### 13.1 Minimum persisted fields

`direct_payment_requests`:

```text
id, booking_id, customer_user_id, pg_id, owner_user_id
status, version
expected_amount_paise, currency
pricing_snapshot_json, policy_snapshot_json
destination_version_id, owner_name_snapshot, upi_vpa_snapshot, mobile_mask_snapshot
customer_claimed_amount_paise, customer_reference_normalized
customer_claimed_paid_at, claim_submitted_at, proof_document_id
payment_window_ends_at, owner_review_ends_at
owner_received_amount_paise, owner_decision, owner_reason, owner_decided_at
payment_id, receipt_id
created_at, updated_at
```

Use separate append-only event, refund, consent, notification-outbox, and dispute tables. Put unique constraints on booking/request payment linkage and the normalised reference scope chosen by the risk design. Do not rely only on application-side duplicate checks.

## 14. Data visibility, retention, and deletion

Visibility:

- customer: their profile, booking snapshots, destination used for their active request, owner decision, refund, and dispute;
- owner: only customers requesting/occupying their PG, with DAY_WISE or MONTHLY fields appropriate to that booking;
- admin/support: least-privilege, audited access for verification/dispute work;
- public users and other owners/customers: no profile, address, identity, payment-reference, proof, or destination data.

Retention rules:

- raw Aadhaar credential/share code/QR payload: delete immediately after verification; never include in backup exports or logs;
- Aadhaar structured data: last four only when necessary, plus verification/consent metadata; erase when its documented purpose and lawful retention end;
- abandoned direct request with no payment claim: minimise and automatically delete/anonymise after the configured short operational period;
- payment claims, approvals, receipts, refunds, disputes, and immutable policy/price snapshots: retain for the documented accounting, tax, consumer-dispute, and legal-claims period selected by counsel, then delete/anonymise where permitted;
- proof screenshots: delete sooner than ledger records when the dispute/refund purpose is resolved and no law requires continued retention;
- current/permanent address: do not retain indefinitely merely because it was once provided; tie deletion to occupancy, legal records, active disputes, and the published schedule;
- security/fraud metadata and audit logs: separate purpose, access control, and finite retention schedule;
- backups: apply eventual deletion and restricted restore procedures rather than treating backups as permanent identity archives.

Publish the schedule in the Privacy Notice and implement automated jobs with auditable deletion outcomes. Provide correction, access, withdrawal/erasure where applicable, and grievance routes. Withdrawal cannot rewrite completed financial records that must lawfully be retained, but unrelated future processing must stop.

## 15. Acceptance criteria

- A customer missing MONTHLY address/identity fields can still book DAY_WISE when DAY_WISE requirements are satisfied.
- Selecting a non-Aadhaar identity method provides equivalent booking access.
- Aadhaar UI is absent while OVSE integration is disabled, and no endpoint accepts a full Aadhaar number.
- Terms, privacy, monthly policy, Aadhaar, and direct-payment acknowledgements are separate and versioned.
- The direct option is unavailable for unverified/suspended owners or destinations.
- Owner detail changes cannot alter an existing request's destination snapshot.
- Customer `I Have Paid` moves only to `OWNER_REVIEW_PENDING` and never allocates a bed.
- Owner approval with an amount one paise below/above expected is rejected.
- Concurrent approval, expiry, cancellation, and competing-booking tests produce at most one booking/payment outcome.
- Repeating claim/approval requests with the same idempotency key cannot duplicate payment or allocation.
- Approval after deadline or after inventory loss fails and creates the appropriate refund/reconciliation action.
- Razorpay capture still confirms without owner approval and direct-payment states cannot be used to spoof it.
- Rejected/expired direct claims have a dispute route and immutable evidence.
- Direct refunds are never labelled completed without owner reference and the defined customer confirmation/dispute state.
- Cross-owner and cross-customer access tests fail with no metadata leakage.
- Notification tests prove deduplication and escalation. Production feature enablement fails closed while real delivery is unavailable.
- UI tests do not rely only on color and use accessible labels for payment/booking states.

## 16. Deployment and launch checklist

- [ ] Obtain state/city-specific review of PG registration, guest/tenant or police-verification records, accommodation agreements, minimum-age rules, and required identity documents.
- [ ] Obtain counsel/accounting review of marketplace role, Consumer Protection (E-Commerce) duties, grievance handling, cancellation/no-show terms, direct refunds, receipts/invoices, GST, deposits, and platform fees.
- [ ] Publish owner, customer, booking, cancellation/refund, privacy, Aadhaar, direct-payment, and grievance terms with versioning.
- [ ] Keep `CUSTOMER_AADHAAR_VERIFICATION_ENABLED=false` until UIDAI OVSE registration and approved integration are complete.
- [ ] Keep `DIRECT_OWNER_PAYMENT_ENABLED=false` until owner/destination validation and real notifications are production-ready.
- [ ] Validate every direct-payment owner and destination; test rotation/suspension and snapshot behavior.
- [ ] Decide how platform revenue works when money bypasses Razorpay Route.
- [ ] Provision production push and/or transactional notification provider, retries, dead-letter monitoring, and support escalation.
- [ ] Keep identity/payment proof storage private; enable malware/content validation, short-lived signed URLs, encryption, and audited access.
- [ ] Complete Razorpay test/live onboarding, Route linked accounts, webhook secret rotation procedure, capture/refund/reconciliation tests, and failure drills.
- [ ] Run concurrency, idempotency, authorization, amount-tampering, timeout, refund, dispute, rate-limit, and notification tests.
- [ ] Add dashboards/alerts for owner response SLA, expired claims with possible funds, refund backlog, rejection/fraud anomalies, duplicate references, and notification failures.
- [ ] Train support not to mark a direct payment received without the owner workflow and not to request full Aadhaar over chat/email.
- [ ] Pilot with a small verified owner group and low limits before broad release.

## 17. Legal and provider references

Primary official sources used for this design:

- [Aadhaar Act, 2016 as amended — voluntary use, alternatives, purpose restrictions](https://uidai.gov.in/images/Aadhaar_Act_2016_as_amended.pdf)
- [UIDAI Aadhaar Authentication and Offline Verification Regulations, updated December 2025](https://www.uidai.gov.in/images/The_Aadhaar_Authentication_and_Offline_Verifications_Regulations_2021-_Clean_copy-30122025.pdf)
- [UIDAI OVSE registration](https://www.uidai.gov.in/hi/ovse)
- [UIDAI Aadhaar Paperless Offline e-KYC guidance](https://uidai.gov.in/en/307-faqs/authentication/offline-aadhaar-data-verification-service.html)
- [UIDAI definition of Masked Aadhaar](https://www.uidai.gov.in/en/283-faqs/aadhaar-online-services/e-aadhaar/1887-what-is-masked-)
- [Digital Personal Data Protection Act, 2023](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf)
- [Digital Personal Data Protection Rules, 2025 and phased commencement](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf)
- [Current DPDP commencement annotations on India Code](https://www.indiacode.nic.in/bitstream/123456789/22037/2/a2023-22.pdf)
- [Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011](https://www.meity.gov.in/sites/upload_files/dit/files/GSR313E_10511%281%29.pdf)
- [Consumer Protection (E-Commerce) Rules and related official materials](https://consumeraffairs.nic.in/acts-and-rules/consumer-protection/consumer-protection)
- [Razorpay Flutter Checkout integration and mandatory server signature verification](https://razorpay.com/docs/payments/payment-gateway/flutter-integration/standard/integration-steps/)
- [Razorpay webhook validation and idempotency guidance](https://razorpay.com/docs/webhooks/validate-test/)
- [Razorpay Route marketplace and linked-account overview](https://razorpay.com/route/)

As of 22 September 2026, most substantive DPDP obligations are scheduled to commence eighteen months after 13 November 2025. The product should nevertheless be built to the notified notice, consent, minimisation, security, rights, and erasure model now. Aadhaar-specific requirements and the currently applicable IT/privacy framework must not be deferred.

Before deployment, qualified counsel must validate this design against the exact states/cities served. PG, hostel, lodging, tenancy/licence, police-verification, tax, invoice, and record-retention requirements are jurisdiction-specific and cannot be safely inferred from a national product specification alone.
