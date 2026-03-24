/*==============================================================
  FILE: feature_engineering.sql
  PURPOSE:
    Build churn and revenue optimization feature layer
    for telecom-style retention analytics.

  DESCRIPTION:
    This query creates a subscriber-level feature dataset with:
      - tenure segmentation
      - 30d / 90d revenue features
      - usage behavior features
      - recency signals
      - churn targeting flags

  NOTES:
    - Oracle SQL style
    - Portfolio/demo version using generic source tables
    - Intended as a production-style feature engineering example
==============================================================*/

WITH
/*==============================================================
  1) SUBSCRIBER BASE
==============================================================*/
subs_base AS (
    SELECT /*+ MATERIALIZE */
           s.subs_id,
           s.activation_date,
           s.status_name,
           s.prod_name,
           s.main_offer_name,
           TRUNC(SYSDATE) - TRUNC(s.activation_date) AS tenure_days
      FROM dwh_coe_data.hier_subs s
     WHERE s.cust_category = 'Private Person'
       AND s.status_name IN ('Active', 'Partial')
       AND NVL(s.is_government, 'N') = 'N'
       AND s.prod_name = 'Mobile Phone'
       AND s.main_offer_name IS NOT NULL
),

/*==============================================================
  2) 30-DAY REVENUE / USAGE AGGREGATION
==============================================================*/
usage_30d AS (
    SELECT /*+ MATERIALIZE */
           u.subs_id,
           SUM(NVL(u.charge, 0))              AS total_charge_30d,
           SUM(NVL(u.data_volume_mb, 0))      AS total_data_mb_30d,
           SUM(NVL(u.voice_minutes, 0))       AS total_voice_min_30d,
           SUM(NVL(u.sms_cnt, 0))             AS total_sms_cnt_30d,
           MAX(TRUNC(u.day))                  AS last_activity_date
      FROM dwh_coe_data.tran_agr_daily_usage u
     WHERE u.day >= TRUNC(SYSDATE) - 29
       AND u.day <  TRUNC(SYSDATE) + 1
     GROUP BY u.subs_id
),

/*==============================================================
  3) 90-DAY REVENUE AGGREGATION
==============================================================*/
usage_90d AS (
    SELECT /*+ MATERIALIZE */
           u.subs_id,
           SUM(NVL(u.charge, 0)) AS total_charge_90d
      FROM dwh_coe_data.tran_agr_daily_usage u
     WHERE u.day >= TRUNC(SYSDATE) - 89
       AND u.day <  TRUNC(SYSDATE) + 1
     GROUP BY u.subs_id
),

/*==============================================================
  4) NOTIFICATION HISTORY (LAST 90 DAYS)
==============================================================*/
notif_90d AS (
    SELECT /*+ MATERIALIZE */
           k.subs_id,
           COUNT(*)                    AS notifications_90d,
           MIN(TRUNC(k.notif_date))    AS first_notif_date_90d,
           MAX(TRUNC(k.notif_date))    AS last_notif_date_90d
      FROM rep_report.td_cm_kpi_report_ext k
     WHERE k.service = 'SAS'
       AND TRUNC(k.notif_date) >= TRUNC(SYSDATE) - 89
       AND TRUNC(k.notif_date) <  TRUNC(SYSDATE) + 1
     GROUP BY k.subs_id
),

/*==============================================================
  5) FEATURE LAYER
==============================================================*/
feature_layer AS (
    SELECT /*+ LEADING(sb) USE_HASH(u30 u90 n90) */
           sb.subs_id,
           sb.activation_date,
           sb.status_name,
           sb.prod_name,
           sb.main_offer_name,
           sb.tenure_days,

           /*------------------------------
             TENURE BIN
           ------------------------------*/
           CASE
               WHEN sb.tenure_days <= 365  THEN '0-1y'
               WHEN sb.tenure_days <= 730  THEN '1-2y'
               WHEN sb.tenure_days <= 1095 THEN '2-3y'
               WHEN sb.tenure_days <= 1460 THEN '3-4y'
               ELSE '4y+'
           END AS tenure_bin,

           /*------------------------------
             30D FEATURES
           ------------------------------*/
           NVL(u30.total_charge_30d, 0)     AS total_charge_30d,
           NVL(u30.total_data_mb_30d, 0)    AS total_data_mb_30d,
           NVL(u30.total_voice_min_30d, 0)  AS total_voice_min_30d,
           NVL(u30.total_sms_cnt_30d, 0)    AS total_sms_cnt_30d,

           /*------------------------------
             90D FEATURES
           ------------------------------*/
           NVL(u90.total_charge_90d, 0)     AS total_charge_90d,

           /*------------------------------
             RECENCY
           ------------------------------*/
           u30.last_activity_date,
           CASE
               WHEN u30.last_activity_date IS NOT NULL
               THEN TRUNC(SYSDATE) - u30.last_activity_date
               ELSE 999
           END AS days_since_last_activity,

           /*------------------------------
             CAMPAIGN FEATURES
           ------------------------------*/
           NVL(n90.notifications_90d, 0)       AS notifications_90d,
           n90.first_notif_date_90d,
           n90.last_notif_date_90d,

           /*------------------------------
             VALUE SEGMENT
           ------------------------------*/
           CASE
               WHEN NVL(u90.total_charge_90d, 0) < 20 THEN 'Low'
               WHEN NVL(u90.total_charge_90d, 0) < 50 THEN 'Medium'
               WHEN NVL(u90.total_charge_90d, 0) < 100 THEN 'High'
               ELSE 'VIP'
           END AS value_segment,

           /*------------------------------
             USAGE MIX
           ------------------------------*/
           CASE
               WHEN NVL(u30.total_data_mb_30d, 0) >= NVL(u30.total_voice_min_30d, 0) * 10
               THEN 'Data-heavy'
               ELSE 'Balanced/Voice'
           END AS usage_mix,

           /*------------------------------
             HIGH-VALUE FLAG
           ------------------------------*/
           CASE
               WHEN NVL(u90.total_charge_90d, 0) >= 20 THEN 1
               ELSE 0
           END AS high_value_flag,

           /*------------------------------
             ACTIVITY RISK FLAG
           ------------------------------*/
           CASE
               WHEN
                    CASE
                        WHEN u30.last_activity_date IS NOT NULL
                        THEN TRUNC(SYSDATE) - u30.last_activity_date
                        ELSE 999
                    END >= 30
               THEN 1
               ELSE 0
           END AS inactivity_risk_flag

      FROM subs_base sb
      LEFT JOIN usage_30d u30
        ON sb.subs_id = u30.subs_id
      LEFT JOIN usage_90d u90
        ON sb.subs_id = u90.subs_id
      LEFT JOIN notif_90d n90
        ON sb.subs_id = n90.subs_id
),

/*==============================================================
  6) SIMPLE DEMO CHURN SCORE
     NOTE:
     In production, replace with model output table
==============================================================*/
scored_features AS (
    SELECT f.*,

           ROUND(
               1 / (
                   1 + EXP(
                       -(
                           -2.20
                           + 0.012 * f.days_since_last_activity
                           - 0.00018 * f.total_data_mb_30d
                           - 0.00150 * f.total_voice_min_30d
                           - 0.00080 * f.tenure_days
                           + 0.03000 * f.notifications_90d
                           - 0.01000 * f.total_charge_30d
                       )
                   )
               ),
               6
           ) AS churn_prob

      FROM feature_layer f
)

/*==============================================================
  7) FINAL OUTPUT
==============================================================*/
SELECT
    sf.subs_id,
    sf.activation_date,
    sf.status_name,
    sf.prod_name,
    sf.main_offer_name,
    sf.tenure_days,
    sf.tenure_bin,
    sf.total_charge_30d,
    sf.total_charge_90d,
    sf.total_data_mb_30d,
    sf.total_voice_min_30d,
    sf.total_sms_cnt_30d,
    sf.last_activity_date,
    sf.days_since_last_activity,
    sf.notifications_90d,
    sf.first_notif_date_90d,
    sf.last_notif_date_90d,
    sf.value_segment,
    sf.usage_mix,
    sf.high_value_flag,
    sf.inactivity_risk_flag,
    sf.churn_prob,

    /*----------------------------------
      TARGETING FLAG
    ----------------------------------*/
    CASE
        WHEN sf.churn_prob >= 0.60
         AND sf.total_charge_90d >= 20
        THEN 1
        ELSE 0
    END AS target_for_retention_flag

FROM scored_features sf;
