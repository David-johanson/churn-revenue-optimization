WITH base AS (
    SELECT
        subs_id,
        churn_prob,
        total_charge_90d,
        actual_churn_flag
    FROM feature_table
),

ranked AS (
    SELECT
        b.*,
        NTILE(10) OVER (ORDER BY churn_prob DESC) AS risk_decile
    FROM base b
)

SELECT
    risk_decile,
    COUNT(*) AS subs,
    AVG(total_charge_90d) AS avg_revenue,
    SUM(CASE WHEN actual_churn_flag = 1 THEN total_charge_90d END) AS revenue_at_risk
FROM ranked
GROUP BY risk_decile
ORDER BY risk_decile;
