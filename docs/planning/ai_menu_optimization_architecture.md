# Sanctuary: AI Menu Optimization Architecture

## 1. AI Pipeline & Data Flow
A production-grade, event-driven intelligence engine that synchronizes market data, guest behavior, and inventory costs.

**The Pipeline:**
Data Collection (Occupancy + Prices) → Consumption Analytics → Cost Precision Engine → Demand Prediction (Time-Series) → Menu Optimization AI → Recommendation Engine.

---

## 2. Intelligence Engines
### Demand Prediction Model (Amazon Forecast Style)
*   **Inputs:** Historical consumption (90 days), Occupancy rate, Day of week, Seasonal trends.
*   **Output:** Predicted servings per meal (Confidence Score: 94%+).

### Profit Maximization Engine (McDonald's Engineering Style)
*   **Logic:** Classifies meals into 4 quadrants:
    1. **Stars:** High Profit + High Demand (Keep/Promote)
    2. **Plowhorses:** Low Profit + High Demand (Cost Optimize)
    3. **Puzzles:** High Profit + Low Demand (Improve Marketing)
    4. **Dogs:** Low Profit + Low Demand (Remove/Replace)

---

## 3. Real-Time Adjustment Engine
*   **Ingredient Spike:** IF ingredient price increases > 10% → AI suggests alternative recipe or price adjustment.
*   **Occupancy Surge:** IF guest check-ins spike unexpectedly → AI adjusts prep quantities and alerts Chef.
*   **Waste Detection:** IF prep quantity > actual consumption + 10% → AI flags as "Excessive Waste" and adjusts next forecast.

---

## 4. Multi-Tenant SaaS Isolation
*   **Tenant Scoping:** All AI training and recommendations are scoped per `hostelId`.
*   **Regional Trends:** AI leverages anonymized regional data to predict ingredient price fluctuations while keeping hostel data private.

---

## 5. Enterprise KPIs
*   **CPG (Cost Per Guest):** Goal ₹45-55/day.
*   **Menu ROI:** (Revenue - Production Cost) / Total Guests.
*   **Waste Efficiency:** Percentage of ingredients converted to served meals.
