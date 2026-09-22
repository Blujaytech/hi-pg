-- One fee can have at most one OPEN (CREATED) checkout at a time.
--
-- V16 gave bookings this guarantee (uq_payment_orders_active_booking); fees
-- never got the equivalent, so two concurrent POSTs to
-- /student/fees/{id}/payment-orders -- which a double-tap on "Pay now"
-- produces -- could both pass PaymentOrderService's "is there an open order?"
-- read and insert two live Razorpay orders for the same fee. Both are
-- payable, so the customer can be charged twice; only the second capture's
-- payment_over_allocation audit warning catches it, and that needs manual
-- reconciliation. CLAUDE.md: "anything touching payments must be safe to run
-- twice (idempotency key + unique constraint)".
--
-- PAID is deliberately not covered: a partially paid fee legitimately needs a
-- second order for the remaining balance, and AUTOPAY writes PAID rows
-- directly. Only one order may be open and awaiting capture at any moment.

-- Collapse any pre-existing duplicates first (keep the newest open order per
-- fee) so the index can be created on live data.
update payment_orders o
   set status = 'FAILED',
       failure_reason = coalesce(o.failure_reason,
           'Superseded by a newer open order for the same fee (V20 backfill)'),
       updated_at = now()
 where o.fee_id is not null
   and o.status = 'CREATED'
   and o.deleted_at is null
   and exists (
       select 1
         from payment_orders newer
        where newer.fee_id = o.fee_id
          and newer.status = 'CREATED'
          and newer.deleted_at is null
          and (newer.created_at, newer.id) > (o.created_at, o.id)
   );

create unique index uq_payment_orders_open_fee
    on payment_orders (fee_id)
    where fee_id is not null
      and status = 'CREATED'
      and deleted_at is null;
