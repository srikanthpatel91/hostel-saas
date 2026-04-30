# Sanctuary: Financial & Marketplace Master Design

## 1. Unified Financial Engine
A multi-tenant SaaS architecture where every transaction is scoped by `hostelId` to ensure data isolation and security.

### Core Payment Model
Every transaction follows a strictly typed model:
- `transactionId`, `hostelId`, `userId`, `role`
- `type`: RENT, SUBSCRIPTION, SERVICE, REFERRAL, REFUND
- `status`: PENDING, SUCCESS, FAILED, ROLLBACK_PENDING, ROLLED_BACK

## 2. Marketplace & Escrow Logic
Service marketplace payments (Laundry, Bike Wash, etc.) use an escrow-style flow:
1. **Booking:** Guest pays; funds are held in Escrow.
2. **Completion:** Worker marks task as done; Owner/Guest confirms.
3. **Payout:** Platform fee (e.g., 10%) is deducted; remainder is released to Vendor wallet.

## 3. Subscription Billing (SaaS Core)
Automated billing for hostel owners based on their chosen plan:
- **Plans:** Basic, Pro, Enterprise.
- **Cycle:** Monthly auto-renewal with 3-retry logic for failures.
- **Grace Period:** 7 days before service limitation.

## 4. Wallet & Real-Time Ledger
Triple-bucket wallet system for every user role:
- **Main Wallet:** Withdrawable funds (Rent income, Vendor payouts).
- **Bonus/Referral Wallet:** Non-withdrawable credits for in-app services.
- **Pending/Escrow:** Funds locked during verification or service execution.

## 5. Rollback & Fraud Protection
- **Atomic Reversals:** Every transaction supports a linked reversal to ensure ledger integrity.
- **AI Fraud Layer:** Real-time risk scoring, duplicate payment detection, and device fingerprinting.
