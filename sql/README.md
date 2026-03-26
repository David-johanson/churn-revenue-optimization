# SQL Portfolio — Telecom Analytics

This repository showcases production-style SQL pipelines used in telecom analytics, focusing on churn reduction, revenue optimization, and campaign targeting.

---

## 🔥 Featured Project: UC05 Scale-up Pipeline

A production-grade Oracle SQL pipeline for dynamic subscriber targeting.

### What it does:
- Identifies eligible subscribers based on usage behavior
- Applies revenue-based filtering (30-day rolling charges)
- Integrates ML model predictions
- Assigns personalized offers
- Maintains a 30-day retention lifecycle

### Business Value:
- Increases ARPU via targeted upsell campaigns
- Enables precision marketing
- Supports churn prevention strategy

---

## 📂 Repository Structure

sql/
uc05_scaleup_pipeline.sql # Main campaign pipeline
feature_engineering.sql # Feature layer for modeling
revenue_at_risk.sql # Churn revenue analysis

data/ # Sample / placeholder
notebooks/ # Analysis notebooks
outputs/ # Charts and results


---

## ⚙️ Tech Stack

- Oracle SQL (PL/SQL)
- Large-scale data processing (millions of subscribers)
- GTT-based pipelines
- MERGE / DELETE incremental refresh
- Performance tuning (hints, partition pruning)

---

## 📊 Key Techniques

- Rolling window aggregations (30/60/90 days)
- Behavioral segmentation
- Model-driven targeting
- Retention window logic
- Campaign eligibility filtering

---

## 🧠 Author

David Jokhadze  
Data Analyst — Telecom Analytics  
SQL | Python | BI | Churn Modeling
