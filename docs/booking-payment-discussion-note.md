# Booking and payment discussion note

This is the current product agreement to use while implementing the next booking and payment features. It is intentionally short and can be updated when a decision changes.

## 1. Room and bed booking configuration

- A PG owner can configure a room as `MONTHLY`, `DAY_WISE`, or `MIXED`.
- `MONTHLY`: all beds in that room are offered for monthly stays by default.
- `DAY_WISE`: all beds in that room are offered for short stays by default.
- `MIXED`: the owner must be able to configure individual beds as monthly, day-wise, or flexible.
- Room settings provide the default, but an authorised owner can customise individual beds.
- Existing confirmed bookings must never be changed or removed by a later configuration change.
- Configuration changes that conflict with an existing booking must be rejected or start from a valid future date.
- Online bookings, offline occupants, maintenance blocks, and payment holds must use the same bed calendar so that a bed cannot be double-booked.

## 2. Calendar presentation

The owner sees a detailed room-and-bed calendar. The customer sees only availability and booking type, without another occupant's private information.

Suggested visual language:

- Purple: monthly booking/availability
- Blue: day-wise booking/availability
- Teal: flexible or both modes available
- Yellow: temporary hold or payment pending
- Grey: unavailable, maintenance, or owner-blocked
- Orange: offline/walk-in occupancy
- Red indicator: overdue payment or action required (owner view only)
- Green: available

Every colour must also have a text label or icon for accessibility.

## 3. Payment gateway requirements

The gateway integration must support:

- UPI
- Debit cards
- Credit cards
- Net banking
- Recurring payments/AutoPay
- Marketplace owner accounts and split settlement
- Platform commission
- Refunds, reversals, webhooks, and reconciliation

Razorpay Checkout + Route + Subscriptions is the selected implementation. Checkout handles UPI/cards/netbanking, Route sends the owner share to the verified linked account, and Subscriptions provides the customer-authorised monthly mandate. Credentials, webhook configuration, Route activation, and commercial approval are deployment prerequisites.

Direct payment to an owner's personal QR code is not the normal online-booking flow.

## 4. AutoPay flow

- A monthly customer authorises the AutoPay mandate when joining or enabling AutoPay. Customer mandate consent is mandatory.
- After the mandate exists, the system attempts the monthly debit automatically on the due date. The owner does not approve every debit.
- A credit-card payment can succeed when the customer has available credit even if their savings-account balance is low; the platform itself is not giving the customer credit.
- Payment is confirmed only from a verified gateway webhook, not from the client success screen.
- A manual `Pay now` option remains available.
- If the customer pays manually, any scheduled retry must be cancelled or ignored idempotently to prevent double collection.

AutoPay result:

```text
Due date reached
  -> AutoPay attempt
     -> Success: mark PAID, issue receipt, notify owner and customer
     -> Failure: mark AUTOPAY_FAILED, notify owner and customer, allow extension
```

## 5. Fee reminders and owner notifications

Example: rent is due on September 20.

- Before September 20: remind the customer according to the configured reminder schedule.
- September 20, if still unpaid: notify both customer and owner.
- September 23, if still unpaid and no active extension: notify both again and show the fee as overdue/action required.
- Further reminders must be controlled to avoid duplicate or excessive notifications.
- Notification delivery must be idempotent: one scheduled event must not create duplicate messages.

## 6. Payment extension

- After a failed AutoPay attempt, the customer can discuss/request more time from the owner.
- The owner can grant an extension by selecting a new due date and adding an optional note.
- The original due date and every extension remain in the audit history.
- During an approved extension, overdue escalation is paused and reminders are recalculated using the extended date.
- On the extended date, the system retries AutoPay if supported and scheduled; otherwise it prompts the customer to pay manually.
- If the extended deadline also passes unpaid, the fee returns to `OVERDUE` and both parties are notified.
- The owner may grant another extension, and every extension must remain visible to admin.

Example:

```text
Original due date: September 20
AutoPay failed: September 20
Owner extends until: September 25
Paid by September 25 -> PAID
Not paid by September 25 -> OVERDUE after extension
```

## 7. Notice period and move-out

- Each property/room can have an owner-configured notice period, such as 5, 10, 15, or 30 days.
- The applicable notice period must be shown before booking and accepted in the PG agreement.
- The accepted policy is saved with the customer's stay and cannot be changed for that stay without mutual agreement.
- The customer submits a move-out notice in the app with the intended last date.
- Leaving the PG does not cancel already accrued rent or other valid dues.

## 8. Security deposit and final settlement

- Do not use CIBIL or claim that unpaid PG rent automatically changes a formal credit score.
- The owner's protection is the agreed security deposit, notice-period terms, overdue tracking, and internal account restrictions.
- The security deposit is separate from rent and platform revenue.
- Deposit adjustment normally happens at move-out/final settlement, not immediately after every failed monthly payment.
- Permitted deductions can include unpaid rent, agreed notice-period shortfall, verified utility charges, and verified damage, subject to the signed agreement.
- Every deduction must be itemised and shown to the customer.
- Any remaining deposit is refunded according to the agreed timeline.
- If the deposit is insufficient, the remainder stays as an internal outstanding balance and may prevent a new booking until resolved.

Final statement example:

```text
Unpaid rent
+ valid notice-period shortfall
+ verified utilities/damage
- deposit applied
- payments already received
= refund due or outstanding balance
```

## 9. Important implementation safeguards

- Prevent overlapping bookings at the database/transaction level, not only in the UI.
- Use temporary holds during checkout and release expired/failed holds.
- Store payment, mandate, refund, extension, deposit-adjustment, and notification history as auditable records.
- Process gateway webhooks idempotently.
- Never store raw card credentials.
- Keep customer-visible policies and the exact policy snapshots accepted for each booking.

## 10. Operational decisions still required before production launch

- Razorpay commercial approval and live Route/Subscriptions activation
- Exact platform commission and who bears gateway charges
- AutoPay retry rules supported by the selected provider
- Exact reminder schedule beyond due date and day three
- Deposit amount and refund timeline
- Default notice period per property type
- Cancellation, no-show, dispute, and late-fee policies
- Accounting, GST, agreement, and legal review
