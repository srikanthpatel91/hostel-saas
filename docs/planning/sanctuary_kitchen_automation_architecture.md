# Sanctuary: Hostel Kitchen Automation & Integration Architecture

## 1. The Closed-Loop Ecosystem
A fully integrated, real-time "Food Operating System" where every guest action triggers a backend inventory and financial event.

**The Loop:** Guest Booking → Real-time Inventory Deduction → Staff Execution → Analytics → Auto-Refill.

---

## 2. Technical Architecture & Integration
### System Flow
1. **Guest App:** Browses menu and books a meal.
2. **Meal Engine:** Validates portion availability and confirms booking.
3. **Inventory Deduction Engine:** Automatically subtracts ingredients (Rice, Oil, Veg) from stock based on recipe mapping.
4. **Kitchen Dashboard (Staff):** Receives the prep order with a live checklist.
5. **Prediction Engine:** Recalculates "Days Left" and stock velocity based on the new consumption event.
6. **Auto-Purchase System:** Triggers a supplier PO if stock falls below the minimum threshold.

### Integration Points
* **Guest → Kitchen:** Booking triggers atomic inventory deduction.
* **Hostel → Kitchen:** Occupancy data (total guests) helps predict bulk prep requirements.
* **Kitchen → Finance:** Automated food cost tracking (cost per meal/per guest) for the Owner's ledger.

---

## 3. Automation & AI Rules
* **Rule 1 (Low Stock):** IF stock < 20% → Auto-generate purchase suggestion for Owner.
* **Rule 2 (Demand Spike):** IF daily consumption increases by >20% → Adjust prediction velocity and alert for early restock.
* **Rule 3 (Wastage):** IF meal bookings vs. inventory deduction shows an anomaly → Flag for audit.

---

## 4. Financial & Inventory Model
Every ingredient is tracked as a `transactionId` in the kitchen ledger:
* **Inputs:** Supplier deliveries, purchase orders.
* **Outputs:** Meal consumption (automated), manual wastage/damage logs.
* **Metrics:** Cost per guest (e.g., Target: ₹48/day), Inventory Efficiency Score.

---

## 5. Security & Traceability
* **Owner:** Full approval rights for purchases and cost analytics.
* **Kitchen Manager:** Inventory management and recipe mapping.
* **Staff:** Task execution and consumption updates only.
* **Audit Trail:** "Who, What, When" for every gram of stock moved.
