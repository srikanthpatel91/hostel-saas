# Sanctuary: Payment & Rollback System (Financial Safety Engine)

## 1. Core Financial Logic
A production-grade system ensuring 100% transaction integrity, zero duplicate charges, and automatic failure recovery.

### Payment Flow
`Booking Initiated` → `Payment Hold` → `Gateway Processing` → `Success OR Failure` → `Ledger Update` → `Booking Confirm/Cancel` → `Rollback (if needed)`

---

## 2. Payment State Machine
Transactions must transition through these states linearly:
- **INITIATED:** Transaction started.
- **PENDING:** Waiting for gateway response.
- **PROCESSING:** In-flight with bank/gateway.
- **SUCCESS:** Funds captured; Ledger updated.
- **FAILED:** Transaction declined or errored.
- **ROLLED_BACK:** System state restored after failure.

---

## 3. Automatic Rollback Engine
Triggered on any failure (timeout, gateway error, user cancel):
1. **Cancel Booking:** Status set to 'Cancelled'.
2. **Release Inventory:** Bed/Room lock released immediately.
3. **Wallet Reversal:** Credits returned to Bonus/Available wallet.
4. **Ledger Entry:** Create a 'Reversal' record for audit.

---

## 4. Double-Entry Ledger System
Stripe-style immutable ledger for every cent:
- **Transaction ID:** Unique hash.
- **Accounts:** Mapping from `Debit` to `Credit`.
- **Integrity Rule:** Every debit must have a matching credit; no orphan transactions.
- **Idempotency:** `paymentId + userId + bookingId` key prevents duplicate charges.

---

## 5. Security & Fraud Layer
- **Risk Scoring:** Integration with the Sanctuary Fraud Engine.
- **Hold System:** Authorize first, capture only on success.
- **Audit Logs:** Full traceability of "Who, What, When, and Result" for every financial event.
