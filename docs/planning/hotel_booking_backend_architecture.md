# Hotel Booking Application: Backend System Architecture

## 1. Data Models (Database Design)

### Users Collection
```json
{
  "userId": "string",
  "name": "string",
  "email": "string",
  "phone": "string",
  "role": "GUEST | OWNER | ADMIN",
  "createdAt": "timestamp"
}
```

### Rooms Collection
```json
{
  "roomId": "string",
  "hostelId": "string",
  "roomNumber": "string",
  "type": "SINGLE | DOUBLE | DORM",
  "basePrice": "number",
  "amenities": ["string"],
  "status": "AVAILABLE | MAINTENANCE | BLOCKED"
}
```

### Bookings Collection
```json
{
  "bookingId": "string",
  "userId": "string",
  "roomId": "string",
  "checkInDate": "date",
  "checkOutDate": "date",
  "status": "DRAFT | PENDING | CONFIRMED | CHECKED_IN | COMPLETED | CANCELLED",
  "totalAmount": "number",
  "paymentId": "string",
  "lockExpiry": "timestamp",
  "createdAt": "timestamp"
}
```

## 2. Real-Time Availability Engine
### Preventing Double Booking & Date Overlaps
**Logic:** Use a Transactional Query to check for any existing bookings that overlap with the requested dates.
**Query:**
`SELECT * FROM Bookings WHERE roomId = :roomId AND status IN ('PENDING', 'CONFIRMED', 'CHECKED_IN') AND (checkInDate < :requestedCheckOut AND checkOutDate > :requestedCheckIn)`

### Concurrency Handling (Temporary Lock)
1. **Initiate:** When a user selects a room, create a `DRAFT` booking with a `lockExpiry` (5–10 mins).
2. **Validate:** The availability engine treats `LOCKED` (DRAFT/PENDING) rooms as unavailable.
3. **Release:** A background worker/cron job automatically transitions `DRAFT/PENDING` bookings to `EXPIRED/CANCELLED` if `now > lockExpiry` and payment is not confirmed.

## 3. Pricing Engine
### Calculation Flow
`Base Price * Nights` + `Taxes (GST)` + `Service Fees` - `Discounts/Coupons` = `Total Amount`

- **Seasonal Pricing:** Middleware adjusts `Base Price` based on date ranges (e.g., +20% during festivals).
- **Coupons:** Validates `couponCode` against a `Coupons` collection before final total calculation.

## 4. Booking Lifecycle States
- **DRAFT:** Initial selection, room is temporarily locked.
- **PENDING:** User is at the payment gateway.
- **CONFIRMED:** Payment successful, lock made permanent.
- **CHECKED_IN:** Guest has arrived at the property.
- **COMPLETED:** Guest has checked out.
- **CANCELLED:** User cancelled or payment timed out (Lock released).

## 5. Payment Handling
- **Success:** Transition status to `CONFIRMED`.
- **Failure:** Allow `Retry` within the lock window; otherwise, `CANCEL` and release room.
- **Refund Logic:** Triggered on `CANCELLED` (if eligible). Record `REFUNDED` transaction in the ledger.

## 6. API Structure (Core Endpoints)
- `POST /bookings/initiate`: Create draft and lock room.
- `GET /rooms/available`: Query available rooms for date range.
- `POST /payments/verify`: Webhook for payment gateway success/failure.
- `POST /bookings/cancel`: User-initiated cancellation.
