# Churn Revenue Optimization

## Overview
This project demonstrates how to identify high-value churners and estimate revenue at risk using telecom-style and casino-style data.

It focuses not only on predicting churn, but on answering the key business question:

> Which customers should we target to maximize retention ROI?

---

## Business Problem
Traditional churn models highlight risk but often ignore **customer value**.

This project bridges that gap by:
- combining churn probability with revenue metrics
- identifying **high-risk + high-value** customers
- estimating **recoverable revenue via retention campaigns**

---

## Key Features

### 1. Feature Engineering
- Tenure segmentation (lifecycle analysis)
- Usage behavior (data vs voice mix)
- Revenue-based segmentation (90-day charge)
- Activity-based signals (recency)

### 2. Churn Analysis
- Probability-based risk segmentation
- Actual vs predicted churn comparison
- Portfolio-level churn KPIs

### 3. Revenue at Risk
- Calculates total revenue from actual churners (90-day window)
- Identifies financially impactful churn segments

### 4. Targeting Strategy
- Filters high-value churners:
  - `churn_prob ≥ 0.60`
  - `total_charge_90d ≥ 20`
- Avoids inefficient mass targeting

### 5. Value Estimation (VE)
Simulates retention campaign impact:

| Retention Rate | Revenue Saved |
|---------------|--------------|
| 10% | Scenario-based |
| 20% | Scenario-based |
| 30% | Scenario-based |

### 6. Revenue Lift Curve
- Shows how much revenue can be captured by targeting top-risk users
- Demonstrates prioritization efficiency

---

## Example Insights

- Top ~10% highest-risk users contribute a disproportionate share of revenue at risk  
- High-value churners (≥20 GEL) represent the most impactful retention opportunity  
- Targeted campaigns significantly outperform broad campaigns in efficiency
  
## Key Results

- Top ~10% highest-risk users capture ~25–35% of total revenue at risk  
- High-value churners (≥20 GEL) represent the most impactful retention segment  
- Targeted approach reduces campaign size while preserving majority of revenue  
- Retention simulation shows strong upside even at 10–20% success rates  
---

## Tech Stack

- **SQL (Oracle-style logic)** — feature engineering, aggregation
- **Python (Pandas, NumPy)** — analysis & simulation
- **Jupyter Notebook** — end-to-end workflow
- **Matplotlib** — visualization

---

## Project Structure
churn-revenue-optimization/
│
├── notebooks/
│ └── churn_analysis.ipynb
│
├── sql/
│ └── feature_engineering.sql
│
├── data/
│ └── (sample / simulated data)
│
├── outputs/
│ └── charts/
│
└── README.md




---

## Business Impact

This project demonstrates how analytics directly supports revenue-driven decision making:

- Identifies **high-value customers at risk of churn** (not just high-risk)
- Quantifies **revenue at risk (90-day horizon)** before campaign launch
- Enables **ROI-driven targeting strategy** instead of mass campaigns
- Shows how **top-risk segments contribute disproportionately to revenue loss**
- Provides a clear framework for **retention value estimation (VE)**

👉 Key takeaway:  
Focusing on high-value churners significantly improves campaign efficiency and expected return.

---

## Extensions (Next Steps)

- Train and evaluate churn prediction models
- Add campaign cost → full ROI calculation
- Build Power BI / Tableau dashboard
- Implement uplift modeling (true incremental impact)
- Deploy pipeline with SQL + Python integration

---

## About Me

**David Johanson**  
Data Analyst | Telecom Analytics | Churn & Revenue Optimization  

- SQL (Oracle, PL/SQL)
- Python (Pandas, analytics workflows)
- Campaign analytics & ARPU analysis
- Feature engineering for ML models

---

## Contact

- GitHub: https://github.com/David-johanson
- Telegram: https://t.me/JOHANSON_D
