# SQL Portfolio — Telecom Analytics

This folder contains production-style Oracle SQL pipelines used for telecom analytics, focusing on churn reduction, revenue optimization, and campaign targeting.

---

## 🧩 Pipelines Overview

### 1. UC05 Scale-up Pipeline (`uc05_scaleup_pipeline.sql`)

A production-grade pipeline for building a **daily dynamic subscriber targeting table**.

#### Key Logic:
- Filters eligible subscribers using 90-day usage behavior
- Applies revenue constraints (`Last_Mix_Charge BETWEEN 0 AND 35`)
- Integrates ML model predictions (Mix propensity)
- Assigns personalized offers (`Offer1–Offer4`)
- Maintains a **30-day retention window** using `Last_Eligible_Date`

#### Core Features:
- Daily incremental refresh (MERGE-based)
- Retention-aware logic (keeps users for 30 days)
- Handles missing model predictions (retained users with NULL offers)
- Prevents data quality issues via pre-flight checks

---

### 2. Revenue at Risk (`revenue_at_risk.sql`)

Calculates financial exposure from churners.

#### Key Logic:
- Aggregates 90-day revenue before churn (`TOTAL_CHARGE_BEF_90`)
- Segments customers by value thresholds
- Supports campaign prioritization (high-value churners)

#### Use Cases:
- Revenue exposure estimation
- Campaign targeting strategy
- Value-based segmentation

---

### 3. Feature Engineering (`feature_engineering.sql`)

Builds model-ready features for churn prediction.

#### Key Logic:
- Rolling aggregations (30/60/90 days)
- Usage segmentation (data / voice / SMS)
- Tenure-based lifecycle features
- Recency and activity signals

#### Output:
- Subscriber-level feature table for ML models

---

## ⚙️ Technical Design

### Architecture Pattern
Raw Tables → Aggregations → GTT Staging → Final Table (MERGE)


---

### Key Techniques

- **CTE-based modular queries** for readability and maintainability
- **Global Temporary Tables (GTTs)** for intermediate datasets
- **MERGE for incremental updates**
- **DELETE cleanup logic** for retention lifecycle
- **Rolling window aggregations** using pre-aggregated tables

---

## 🚀 Performance Considerations

### Optimizations Used:

- `/*+ MATERIALIZE */` — stabilizes heavy CTE execution
- `/*+ USE_HASH */` — efficient joins on large datasets
- Pre-aggregated tables (`Tran_Agr_Rolling_Totals`) to avoid recomputation
- Early filtering to reduce data volume
- Avoidance of full table scans where possible

---

### Recommended Indexes

```sql
-- Model scoring table
CREATE INDEX idx_scaleup_prob_upd_subs
  ON Dwh_Coe_Data.Coe_Uc05_Scaleup_Prob(Update_Date, Subs_Id);

-- Model predictions
CREATE INDEX idx_model_pred_subs
  ON Dwh_Coe_Data.Coe_Uc05_Su_Mx_Model_Pred(Subs_Id);

-- Rolling aggregations
CREATE INDEX idx_roll_day_type_subs
  ON Dwh_Coe_Data.Tran_Agr_Rolling_Totals(Day, Rolling_Type, Subs_Id);
