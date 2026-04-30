# Sanctuary: Withdrawal, KYC & Fraud Engine Architecture

## 1. Withdrawal & KYC System
### Core Logic
Users cannot withdraw funds without passing a multi-stage verification process.
**Flow:** Request → KYC Check → Fraud Engine Check → Wallet Eligibility → Approval → Payout.

### KYC System Design
*   **Required Docs:** Aadhaar/Passport/ID, Selfie, Phone OTP, Bank Details.
*   **KYC States:** Not Started, Pending, Verified, Rejected.
*   **Verification Flow:** Upload → OCR Scan → Face Match → AI Check → Manual Review.

### Withdrawal States
*   Initiated, KYC_Pending, Under_Review, Approved, Processing, Completed, Rejected.

---

## 2. Fraud Detection AI Logic (Risk Scoring)
### Risk Score (0–100)
*   **0–30:** Safe (Auto-approve)
*   **31–60:** Medium Risk (Manual Review/Hold)
*   **61–100:** High Risk (Block/Limit)

### Risk Factors
1.  **Device Risk (+30):** Multi-accounts on same device, Emulators, Spoofing.
2.  **Behavioral Risk (+20):** Referral bursts, no actual hostel activity.
3.  **Transaction Risk (+25):** Rapid withdrawals, bonus-only usage.
4.  **Network Risk (+20):** Same IP/WiFi farm, shared payment methods.

---

## 3. SaaS Architecture & Microservices
### High-Level System
*   **Frontend:** Guest, Owner, Worker, Vendor Apps.
*   **API Gateway:** Auth, Routing, Guards.
*   **Logic Layer:** Firebase Auth, Business Logic (Cloud Functions), Fraud Engine (AI).
*   **Database:** Firestore (Users, Wallets, KYC, Logs).
*   **External:** Stripe/Razorpay, OCR Services, SMS Gateways.

### Core Microservices
1. **Auth:** Role-based management & OTP.
2. **Wallet:** Ledger system & balance splitting.
3. **Referral:** Attribution & reward rules.
4. **Fraud:** Risk scoring & automated freezing.
5. **KYC:** OCR & Face matching workflow.
6. **Payment:** Payouts & Rent collection.
