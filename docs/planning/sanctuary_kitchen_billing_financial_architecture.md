# Sanctuary: Full Kitchen Billing & Financial Engine Architecture

## 1. System Vision
A production-grade, event-driven engine that automates the financial lifecycle of a hostel kitchen. It ensures that every meal served is accounted for in the ledger, with real-time costing based on current inventory prices.

## 2. Core Billing Logic
### The Transactional Loop
1. **Meal Event:** A guest books or receives a meal (e.g., Lunch Thali).
2. **Recipe Mapping:** The engine fetches the "Bill of Materials" (BOM) for that specific meal.
3. **Inventory Deduction:** Atomic reduction of ingredients (Rice, Oil, Veg) from the `inventory` table.
4. **Live Costing:** The engine calculates the cost based on the `purchasePricePerUnit` of the deducted batch.
5. **Ledger Entry:** An immutable `DEBIT` entry is created in the financial ledger under the `FOOD_COST` category.
6. **Analytics Sync:** Real-time update of the Owner Dashboard (Cost per guest, Daily expense).

---

## 3. Data Models
### Ingredients
```json
{
  "ingredientId": "ING001",
  "name": "Rice",
  "unit": "kg",
  "purchasePricePerUnit": 50,
  "currentStock": 100,
  "hostelId": "H1"
}
```

### Meal Recipe (BOM)
```json
{
  "mealId": "M001",
  "name": "Lunch Thali",
  "ingredients": [
    { "ingredientId": "ING001", "quantity": 0.15 },
    { "ingredientId": "ING002", "quantity": 0.02 },
    { "ingredientId": "ING003", "quantity": 0.2 }
  ]
}
```

### Financial Ledger
```json
{
  "transactionId": "TXN_KITCHEN_992",
  "hostelId": "H1",
  "type": "DEBIT",
  "category": "FOOD_COST",
  "amount": 28.75,
  "reference": "Meal M001 Served - Guest U402",
  "timestamp": "ISO-8601"
}
```

---

## 4. Automation & AI Rules
- **Rule (Price Spike):** IF ingredient cost increases > 10% → Notify Owner to adjust meal pricing or find new supplier.
- **Rule (Wastage):** IF total ingredient deduction > (Meals Served * Recipe Qty) + 15% → Flag for "Excessive Wastage Audit".
- **Rule (Low Stock):** IF `currentStock` < `reorderLevel` → Trigger auto-PO suggestion.

---

## 5. Key Metrics (BI Dashboard)
- **CPG (Cost Per Guest):** Total Daily Cost / Total Active Guests.
- **Recipe Accuracy:** Correlation between theoretical vs. actual inventory usage.
- **Profitability:** Guest Meal Fees - Production Cost.
