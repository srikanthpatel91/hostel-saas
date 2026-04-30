# Sanctuary Financial Engine & Referral System Architecture

## 1. Core Architecture: Single Financial Engine
A unified system that powers all transactions, rewards, and earnings across all user roles (Guest, Owner, Staff, Vendor).

- **Financial Engine Core:** The central ledger and wallet system.
- **Integration Points:** Referral System, Ads System, Service Payments.
- **Output:** Unified User Wallet Balance.

---

## 2. Wallet System Design
### Wallet Types (Triple-Bucket System)
1.  **Available Wallet (Withdrawals/Payments):** Real funds that can be withdrawn or used for rent and services.
2.  **Bonus Wallet (In-App Credits):** Non-withdrawable credits earned from referrals and ads. Spendable only within the Sanctuary ecosystem.
3.  **Pending Wallet (Escrow):** Locked rewards under verification or within the mandatory delay period.

### Data Structure
```json
{
  "userId": "U123",
  "role": "guest",
  "wallet": {
    "available": 500,
    "bonus": 200,
    "pending": 100
  }
}
```

---

## 3. Multi-Role Referral Engine
### Referral Lifecycle
**Invite** → **Signup** → **Activation** → **First Action** → **Reward**

### Role-Based Reward Rules
- **Guest Referral:** Reward unlocked after first rent paid. (Referrer: ₹100 bonus, New User: ₹50 discount).
- **Owner Referral:** Unlocked after 10 bookings or subscription paid. (₹500 – ₹2000 per hostel).
- **Staff Referral:** Unlocked after new staff joins and completes 5 tasks. (₹200 bonus).
- **Vendor Referral:** Unlocked after 10 orders completed. (Commission boost or ₹500 bonus).

---

## 4. Ads Revenue & Monetization
- **Revenue Model:** Platform earns ₹5 per ad; User receives ₹2 (Bonus Wallet); Platform retains ₹3.
- **Rules:** Max 10 ads/day, verified users only.

---

## 5. Transaction Ledger & Integrity
Every movement is recorded in a permanent ledger for audit trails, fraud control, and transparency.

### Ledger Entry
```json
{
  "userId": "U123",
  "type": "credit",
  "source": "referral | ads | payment",
  "amount": 100,
  "walletType": "bonus",
  "status": "completed",
  "timestamp": "ISO-8601"
}
```

---

## 6. Fraud Prevention & Trust
- **Device Locking:** One device restricted to limited accounts.
- **Payment Validation:** Rewards require real transactions.
- **Lock-up Period:** Rewards locked for 3–7 days (Pending Wallet).
- **Anomaly Detection:** Flagging duplicate IPs or devices.
- **Trust Indicators:** Verified badges, KYC status, and transparent ledger views.

---

## 7. UX & Gamification
- **Real-Time Updates:** Instant balance updates and notification toasts.
- **Micro-interactions:** Confetti on reward unlock, counting animations, and glow effects.
- **Empty States:** Encouraging CTAs for users with no activity.
