# Sanctuary: Zero Double Booking Engine Architecture

## 1. Atomic Locking Mechanism
The core of the system is a **Transactional Booking Engine** that prevents race conditions during high-concurrency periods.

### The Locking Flow:
1.  **Availability Check:** Instant read from a real-time database (Firestore/WebSockets).
2.  **Atomic Lock:** When a user clicks "Book Now", a record-level lock is placed on the specific `bedId`.
3.  **Temporary Hold:** The bed status moves to `RESERVED (TEMP)` for a 5-10 minute window.
4.  **Payment Gate:** The lock is only released if the payment succeeds or the timer expires.

## 2. Real-Time State Machine
Beds transition through the following states to ensure consistency:
- **AVAILABLE (Green):** Open for discovery and locking.
- **LOCKED (Blue):** Held during the initial checkout transition.
- **RESERVED (Yellow):** Payment in progress; timer active.
- **CONFIRMED (Red):** Payment successful; ledger entry created; lock permanent.
- **EXPIRED:** Timer hit zero; lock released; bed returns to AVAILABLE.

## 3. Concurrency & Conflict Resolution
- **First Valid Lock Wins:** The system uses optimistic concurrency control. If two users click simultaneously, the first write operation to reach the server "wins" the lock.
- **Conflict UI:** Users who lose the race receive an immediate notification: *"This bed was just booked. Redirecting you to other available options."*

## 4. Financial Integrity
- **Stripe-Level Ledger:** Every booking is tied to a unique transaction ID.
- **No Payment, No Bed:** The `CONFIRMED` status is only reachable via a successful payment gateway callback.
