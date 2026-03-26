# Churn Revenue Optimization

This project simulates a real telecom retention workflow — from churn prediction to revenue-driven targeting and campaign value estimation.

It focuses not only on predicting churn, but on answering the key business question:

> Which customers should we target to maximize retention ROI?

---

## 🧠 Problem Statement

Traditional churn models identify **who is likely to churn**, but fail to answer:

- Which customers actually matter financially?
- How much revenue is at risk?
- What is the expected return of a retention campaign?

This project bridges that gap by combining **churn risk + customer value + targeting strategy**.

---

## 🎯 Solution Overview

The solution integrates three layers:

| Layer | Description |
|------|------------|
| **Feature Engineering** | Behavioral + revenue features (usage, tenure, recency) |
| **Churn Analysis** | Risk segmentation using churn probabilities |
| **Value Optimization** | Revenue-at-risk calculation + targeting strategy |

---

## ⚙️ Key Components

### 1. Feature Engineering
- Tenure segmentation (lifecycle modeling)
- Usage behavior (data vs voice mix)
- Revenue features (30/90-day rolling charges)
- Activity signals (recency & engagement)

### 2. Churn Analysis
- Probability-based segmentation
- Actual vs predicted churn validation
- Portfolio-level churn KPIs

### 3. Revenue at Risk
- Calculates total revenue from actual churners (90-day window)
- Identifies financially impactful churn segments

### 4. Targeting Strategy
Targets only **high-impact customers**:

- `churn_prob ≥ 0.60`
- `total_charge_90d ≥ 20 GEL`

👉 Avoids inefficient mass campaigns

### 5. Value Estimation (VE)
Simulates retention campaign outcomes:

| Retention Rate | Business Interpretation |
|---------------|------------------------|
| 10% | Conservative scenario |
| 20% | Realistic scenario |
| 30% | Optimistic scenario |

### 6. Revenue Lift Curve
- Measures how efficiently revenue is captured
- Demonstrates prioritization of high-risk users

---

## 📊 Key Results

- Top ~10% highest-risk users capture **~25–35% of total revenue at risk**
- High-value churners (≥20 GEL) drive the majority of financial impact
- Targeted campaigns significantly outperform broad campaigns
- Even **10–20% retention success** yields strong revenue recovery

---

## 🧩 SQL Pipelines (Production Layer)

This project includes production-style Oracle SQL pipelines used in telecom environments.

### 🔥 UC05 Scale-up Pipeline
A production-grade pipeline for **dynamic subscriber targeting**:

- Identifies eligible subscribers based on behavior
- Applies revenue-based filtering (30-day rolling charges)
- Integrates ML model predictions
- Assigns personalized offers
- Maintains a 30-day retention lifecycle

### Other SQL Modules
- `feature_engineering.sql` — builds model-ready features
- `revenue_at_risk.sql` — calculates churn-related revenue exposure

📂 Full SQL documentation: [sql/README.md](sql/README.md)

---

## 📂 Project Structure

churn-revenue-optimization/
│
├── sql/
│ ├── uc05_scaleup_pipeline.sql
│ ├── feature_engineering.sql
│ └── revenue_at_risk.sql
│
├── notebooks/
│ └── churn_analysis.ipynb
│
├── data/
├── outputs/
│ └── charts/
│
└── README.md


---

## ⚙️ Tech Stack

- **Oracle SQL (PL/SQL)** — production pipelines, aggregations
- **Python (Pandas, NumPy)** — analysis & simulation
- **Jupyter Notebook** — workflow orchestration
- **Matplotlib** — visualization
- Large-scale data processing (millions of subscribers)

---

## 🔬 Technical Highlights

- Rolling window aggregations (30/60/90 days)
- GTT-based pipeline optimization
- MERGE + DELETE incremental refresh
- Performance tuning (MATERIALIZE, USE_HASH)
- Behavioral + revenue segmentation logic

---

## 💼 Business Impact

This project demonstrates how analytics directly supports revenue-driven decision making:

- Identifies **high-value customers at risk of churn**
- Quantifies **revenue at risk before campaign launch**
- Enables **ROI-driven targeting strategy**
- Reduces campaign size while preserving most revenue
- Improves retention efficiency and expected return

👉 Key takeaway:  
Focusing on high-value churners significantly improves campaign ROI.

---

## 🚀 Next Steps

- Train and evaluate churn prediction models
- Add campaign cost → full ROI calculation
- Build Power BI / Tableau dashboard
- Implement uplift modeling (incremental impact)
- Deploy end-to-end pipeline (SQL + Python)

---

## 👤 Author

**David Jokhadze**  
Data Analyst — Telecom & Revenue Analytics  

- SQL (Oracle, PL/SQL)
- Python (data analysis & modeling support)
- Churn modeling & retention analytics
- Campaign targeting & ARPU optimization

---

## 📈 Visualization

![Revenue Lift Curve](outputs/charts/lift_curve.png)

---

## 📬 Contact

- GitHub: https://github.com/David-johanson
- Telegram: https://t.me/JOHANSON_D
