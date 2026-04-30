# Sanctuary: AI Chef Assistant & Menu Optimization Architecture

## 1. The Intelligence Core
A multi-layered AI system that integrates hostel occupancy, financial ledgering, and real-time market data to automate kitchen operations.

### The Decision Loop
**Data Ingress** (Occupancy, History, Market Prices) → **AI Analysis** (Demand, Cost, Waste) → **Actionable Output** (Auto Menu, Reorder alerts) → **Execution** (Chef Dashboard).

---

## 2. AI Engine Modules
### 1. Demand Prediction Engine
*   **Logic:** Uses time-series forecasting (historical meal counts + current guest check-ins) to predict exact servings per meal.
*   **Impact:** Zero over-cooking; zero stock-outs.

### 2. Cost Optimization Engine
*   **Logic:** Analyzes ingredient price trends and profit margins per recipe.
*   **Impact:** Suggests substitutions (e.g., Seasonal Veg for high-cost imports) to maintain target margins.

### 3. Waste Reduction AI
*   **Logic:** Detects patterns in uneaten food vs. preparation quantity.
*   **Impact:** Dynamically adjusts portion sizes and preparation targets.

---

## 3. Financial & SaaS Integration
*   **Multi-Tenant Isolation:** Every hostel's recipes, costs, and AI models are isolated via `hostelId`.
*   **Stripe-Level Accuracy:** Every gram of ingredient is tied to a financial transaction in the kitchen ledger.
*   **Role-Based Access:** 
    *   **Owner:** Strategy, Profit tracking, AI approval.
    *   **Chef:** Execution, Live recipe adjustments, Task lists.

---

## 4. Key Performance Indicators (KPIs)
*   **CPG (Cost Per Guest):** The primary metric for kitchen profitability.
*   **Recipe Compliance:** Tracking how closely the kitchen team follows AI-optimized recipes.
*   **Wastage Rate:** Percentage of ingredients purchased vs. meals served.
