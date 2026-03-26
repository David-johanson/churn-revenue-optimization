/*==============================================================
  FILE: uc05_scaleup_pipeline.sql

  PROJECT: Churn & Revenue Optimization

  PURPOSE:
    Build and maintain a daily dynamic subscriber base for
    a Mix Package Scale-up campaign (UC05 use case).

  OVERVIEW:
    This pipeline:
      - Identifies eligible prepaid subscribers
      - Applies behavioral and eligibility filters
      - Calculates rolling revenue metrics
      - Integrates model scoring outputs
      - Assigns personalized offers
      - Maintains a 30-day retention window

  BUSINESS IMPACT:
    Enables targeted upsell campaigns by focusing on
    subscribers with high likelihood to upgrade to
    higher-value mix packages.

  KEY LOGIC:
    - Eligibility based on last 90-day usage behavior
    - Revenue-based filtering (Last_Mix_Charge 0–35 GEL)
    - Model-driven targeting (Mix propensity)
    - Daily refresh with retention tracking
    - Offer assignment with fallback for retained users

  TECH STACK:
    - Oracle SQL (PL/SQL)
    - GTT-based pipeline optimization
    - MERGE + DELETE incremental refresh

  NOTES:
    - Production-style implementation adapted for portfolio use
    - Sensitive business logic generalized
==============================================================*/

/*==============================================================
  PERFORMANCE CONSIDERATIONS

  - Uses pre-aggregated daily usage tables to avoid repeated scans
  - GTT staging reduces repeated heavy joins
  - USE_HASH / MATERIALIZE hints stabilize execution on large data
  - Range predicates preserve index eligibility on Update_Date
  - Pre-flight checks prevent catastrophic empty/duplicate loads

  RECOMMENDED INDEXES (run once, where appropriate):

  CREATE INDEX idx_scaleup_prob_upd_subs
    ON Dwh_Coe_Data.Coe_Uc05_Scaleup_Prob(Update_Date, Subs_Id);

  CREATE INDEX idx_model_pred_subs
    ON Dwh_Coe_Data.Coe_Uc05_Su_Mx_Model_Pred(Subs_Id);

  CREATE INDEX idx_roll_day_type_subs
    ON Dwh_Coe_Data.Tran_Agr_Rolling_Totals(Day, Rolling_Type, Subs_Id);

==============================================================*/

/*--------------------------------------------------------------
  STEP -1: Pre-flight guard
  - Abort if today's scoring output is missing
  - Abort if model prediction snapshot has duplicate Subs_Id
--------------------------------------------------------------*/
DECLARE
  v_Exists NUMBER;
  v_Dupes  NUMBER;
BEGIN
  BEGIN
    SELECT 1
      INTO v_Exists
      FROM Dwh_Coe_Data.Coe_Uc05_Scaleup_Prob
     WHERE Update_Date >= TRUNC(SYSDATE)
       AND Update_Date <  TRUNC(SYSDATE) + 1
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(
        -20001,
        'UC05 aborted: Coe_Uc05_Scaleup_Prob has no rows for '
        || TO_CHAR(TRUNC(SYSDATE), 'YYYY-MM-DD')
        || '. Model scoring job has not completed yet.'
      );
  END;

  SELECT COUNT(*) - COUNT(DISTINCT Subs_Id)
    INTO v_Dupes
    FROM Dwh_Coe_Data.Coe_Uc05_Su_Mx_Model_Pred;

  IF v_Dupes > 0 THEN
    RAISE_APPLICATION_ERROR(
      -20002,
      'UC05 aborted: Coe_Uc05_Su_Mx_Model_Pred contains '
      || v_Dupes
      || ' duplicate Subs_Id row(s) for '
      || TO_CHAR(TRUNC(SYSDATE), 'YYYY-MM-DD')
      || '. Offer prediction load has not completed cleanly.'
    );
  END IF;
END;
/

/*--------------------------------------------------------------
  STEP 0: Clean GTTs
--------------------------------------------------------------*/
TRUNCATE TABLE Tmp_Uc05_Base_Subs;
TRUNCATE TABLE Tmp_Uc05_Charges;
TRUNCATE TABLE Tmp_Uc05_Valid_Base;

/*--------------------------------------------------------------
  STEP 0A: Build structural eligible base -> Tmp_Uc05_Base_Subs
--------------------------------------------------------------*/
INSERT INTO Tmp_Uc05_Base_Subs
  (Subs_Id, Activation_Date)
WITH Usage_Flags AS
 (
  SELECT /*+ MATERIALIZE */
         u.Subs_Id,
         MAX(CASE WHEN bl.Offer_Id IS NOT NULL THEN 1 ELSE 0 END) AS Has_Black,
         MAX(CASE WHEN wh.Offer_Id IS NOT NULL THEN 1 ELSE 0 END) AS Has_White,
         MAX(CASE WHEN UPPER(u.Offer_Name) LIKE '%TOURIST%' THEN 1 ELSE 0 END) AS Is_Tourist
    FROM Dwh_Coe_Data.Tran_Agr_Daily_Usage u
    LEFT JOIN Coe_Uc05_Scaleup_Black_Offers bl
      ON bl.Offer_Id = u.Offer_Id
    LEFT JOIN Coe_Uc05_Scaleup_White_Offers wh
      ON wh.Offer_Id = u.Offer_Id
   WHERE u.Day BETWEEN TRUNC(SYSDATE) - 90 AND TRUNC(SYSDATE)
     AND u.Activity = 'Activation'
     AND u.Offer_Type = 'Package offer'
     AND u.Src IN ('R', 'C')
   GROUP BY u.Subs_Id
 ),
Eligible_By_Usage AS
 (
  SELECT uf.Subs_Id
    FROM Usage_Flags uf
   WHERE uf.Has_Black  = 0
     AND uf.Has_White  = 1
     AND uf.Is_Tourist = 0
 )
SELECT /*+ LEADING(e hs)
           USE_HASH(hs)
           DYNAMIC_SAMPLING(4)
           CARDINALITY(hs 500000) */
       hs.Subs_Id,
       hs.Activation_Date
  FROM Eligible_By_Usage e
  JOIN Dwh_Coe_Data.Hier_Subs hs
    ON hs.Subs_Id = e.Subs_Id
 WHERE hs.Cust_Category = 'Private Person'
   AND hs.Status_Name IN ('Active', 'Partial')
   AND NVL(hs.Is_Government, 'N') = 'N'
   AND hs.Prod_Name = 'Mobile Phone'
   AND hs.Main_Offer_Id IN (755729233, 755732712)
   AND hs.Activation_Date < TRUNC(SYSDATE) - 90
   AND NOT EXISTS
       (
        SELECT 1
          FROM Dwh_Coe_Data.Hier_Subs_Nosms n
         WHERE n.Msisdn = hs.Service_No
       );

/*--------------------------------------------------------------
  STEP 0B: Build today's rolling charges -> Tmp_Uc05_Charges
--------------------------------------------------------------*/
INSERT INTO Tmp_Uc05_Charges
  (Subs_Id, Last_Month_Total_Charge, Last_Mix_Charge)
SELECT r.Subs_Id,
       ROUND(
         SUM(
             NVL(r.Ch_Pg_Pr_Data, 0)   + NVL(r.Ch_Pg_Ob_Data, 0)
           + NVL(r.Ch_Act_Hm_Data, 0)  + NVL(r.Ch_Act_Mx_Data, 0)
           + NVL(r.Ch_Pg_Pr_Voice, 0)  + NVL(r.Ch_Pg_Ob_Voice, 0)
           + NVL(r.Ch_Act_Hm_Voice, 0) + NVL(r.Ch_Act_Mx_Voice, 0)
           + NVL(r.Ch_Pg_Pr_Sms, 0)    + NVL(r.Ch_Pg_Ob_Sms, 0)
           + NVL(r.Ch_Act_Hm_Sms, 0)   + NVL(r.Ch_Act_Mx_Sms, 0)
         ),
         2
       ) AS Last_Month_Total_Charge,
       ROUND(
         SUM(
             NVL(r.Ch_Act_Mx_Sms, 0)
           + NVL(r.Ch_Act_Mx_Voice, 0)
           + NVL(r.Ch_Act_Mx_Data, 0)
         ),
         2
       ) AS Last_Mix_Charge
  FROM Dwh_Coe_Data.Tran_Agr_Rolling_Totals r
 WHERE r.Day = TRUNC(SYSDATE)
   AND r.Rolling_Type = 1
 GROUP BY r.Subs_Id;

/*--------------------------------------------------------------
  STEP 0C: Build valid active base -> Tmp_Uc05_Valid_Base
--------------------------------------------------------------*/
INSERT INTO Tmp_Uc05_Valid_Base
  (Subs_Id, Activation_Date, Last_Month_Total_Charge, Last_Mix_Charge)
SELECT /*+ USE_HASH(c) */
       b.Subs_Id,
       b.Activation_Date,
       c.Last_Month_Total_Charge,
       c.Last_Mix_Charge
  FROM Tmp_Uc05_Base_Subs b
  JOIN Tmp_Uc05_Charges c
    ON c.Subs_Id = b.Subs_Id
 WHERE c.Last_Mix_Charge BETWEEN 0 AND 35;

/*--------------------------------------------------------------
  STEP 1: MERGE into target
--------------------------------------------------------------*/
MERGE INTO Dwh_Coe.Coe_Uc05_Scaleup_With_Off_Pr t
USING
(
  WITH Model_Subs_Today AS
   (
    SELECT /*+ MATERIALIZE */
           DISTINCT sp.Subs_Id
      FROM Dwh_Coe_Data.Coe_Uc05_Scaleup_Prob sp
     WHERE sp.Update_Date >= TRUNC(SYSDATE)
       AND sp.Update_Date <  TRUNC(SYSDATE) + 1
       AND (
             sp.Target_Mix >= 0.5
             OR (
                 sp.Target_Mix > sp.Target_Data
                 AND sp.Target_Mix > sp.Target_Voice
                )
           )
   ),
  Exp5_Today AS
   (
    SELECT /*+ LEADING(v m) USE_HASH(m) */
           v.Subs_Id,
           'Exp5'  AS Experimental_Group,
           'Model' AS Cust_Type,
           v.Last_Month_Total_Charge,
           v.Last_Mix_Charge,
           CASE
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <=  365 THEN '0-1y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <=  730 THEN '1-2y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <= 1095 THEN '2-3y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <= 1460 THEN '3-4y'
             ELSE '4y+'
           END AS Tenure_Bin,
           1 AS Is_Eligible_Today
      FROM Tmp_Uc05_Valid_Base v
      JOIN Model_Subs_Today m
        ON m.Subs_Id = v.Subs_Id
   ),
  Retained_Active AS
   (
    SELECT /*+ MATERIALIZE LEADING(tt v) USE_HASH(v) */
           tt.Subs_Id,
           tt.Experimental_Group,
           tt.Cust_Type,
           v.Last_Month_Total_Charge,
           v.Last_Mix_Charge,
           CASE
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <=  365 THEN '0-1y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <=  730 THEN '1-2y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <= 1095 THEN '2-3y'
             WHEN (TRUNC(SYSDATE) - v.Activation_Date) <= 1460 THEN '3-4y'
             ELSE '4y+'
           END AS Tenure_Bin,
           0 AS Is_Eligible_Today
      FROM Dwh_Coe.Coe_Uc05_Scaleup_With_Off_Pr tt
      JOIN Tmp_Uc05_Valid_Base v
        ON v.Subs_Id = tt.Subs_Id
      LEFT JOIN Exp5_Today et
        ON et.Subs_Id = tt.Subs_Id
     WHERE tt.Last_Eligible_Date IS NOT NULL
       AND TRUNC(SYSDATE) - TRUNC(tt.Last_Eligible_Date) <= 30
       AND et.Subs_Id IS NULL
   ),
  Full_Base AS
   (
    SELECT Subs_Id,
           Experimental_Group,
           Cust_Type,
           Last_Month_Total_Charge,
           Last_Mix_Charge,
           Tenure_Bin,
           Is_Eligible_Today
      FROM
           (
            SELECT x.*,
                   ROW_NUMBER() OVER
                     (PARTITION BY x.Subs_Id
                          ORDER BY x.Is_Eligible_Today DESC) AS rn
              FROM
                   (
                    SELECT Subs_Id,
                           Experimental_Group,
                           Cust_Type,
                           Last_Month_Total_Charge,
                           Last_Mix_Charge,
                           Tenure_Bin,
                           Is_Eligible_Today
                      FROM Exp5_Today
                    UNION ALL
                    SELECT Subs_Id,
                           Experimental_Group,
                           Cust_Type,
                           Last_Month_Total_Charge,
                           Last_Mix_Charge,
                           Tenure_Bin,
                           Is_Eligible_Today
                      FROM Retained_Active
                   ) x
           )
     WHERE rn = 1
   ),
  Model_Offers AS
   (
    SELECT mp.Subs_Id,
           mp.Offer1,
           mp.Offer2,
           mp.Offer3,
           mp.Offer4
      FROM Dwh_Coe_Data.Coe_Uc05_Su_Mx_Model_Pred mp
   )
  SELECT fb.Subs_Id,
         fb.Experimental_Group,
         fb.Cust_Type,
         fb.Last_Month_Total_Charge,
         fb.Last_Mix_Charge,
         fb.Tenure_Bin,
         fb.Is_Eligible_Today,
         mo.Offer1,
         mo.Offer2,
         mo.Offer3,
         mo.Offer4
    FROM Full_Base fb
    LEFT JOIN Model_Offers mo
      ON mo.Subs_Id = fb.Subs_Id
) s
ON (t.Subs_Id = s.Subs_Id)
WHEN MATCHED THEN
  UPDATE
     SET t.Experimental_Group      = s.Experimental_Group,
         t.Cust_Type               = s.Cust_Type,
         t.Last_Month_Total_Charge = s.Last_Month_Total_Charge,
         t.Last_Mix_Charge         = s.Last_Mix_Charge,
         t.Tenure_Bin              = s.Tenure_Bin,
         t.Offer1                  = s.Offer1,
         t.Offer2                  = s.Offer2,
         t.Offer3                  = s.Offer3,
         t.Offer4                  = s.Offer4,
         t.Last_Eligible_Date      = CASE
                                       WHEN s.Is_Eligible_Today = 1
                                         THEN TRUNC(SYSDATE)
                                       ELSE t.Last_Eligible_Date
                                     END,
         t.As_Of_Date              = TRUNC(SYSDATE)
WHEN NOT MATCHED THEN
  INSERT
    (
      Subs_Id,
      Experimental_Group,
      Cust_Type,
      Last_Month_Total_Charge,
      Last_Mix_Charge,
      Tenure_Bin,
      Offer1,
      Offer2,
      Offer3,
      Offer4,
      As_Of_Date,
      Last_Eligible_Date
    )
  VALUES
    (
      s.Subs_Id,
      s.Experimental_Group,
      s.Cust_Type,
      s.Last_Month_Total_Charge,
      s.Last_Mix_Charge,
      s.Tenure_Bin,
      s.Offer1,
      s.Offer2,
      s.Offer3,
      s.Offer4,
      TRUNC(SYSDATE),
      TRUNC(SYSDATE)
    );

/*--------------------------------------------------------------
  STEP 2: Combined DELETE
--------------------------------------------------------------*/
DELETE FROM Dwh_Coe.Coe_Uc05_Scaleup_With_Off_Pr t
 WHERE t.Last_Eligible_Date IS NULL
    OR TRUNC(SYSDATE) - TRUNC(t.Last_Eligible_Date) > 30
    OR NOT EXISTS
       (
        SELECT /*+ HASH_AJ */
               1
          FROM Tmp_Uc05_Valid_Base v
         WHERE v.Subs_Id = t.Subs_Id
       );

/*--------------------------------------------------------------
  STEP 3: Final commit
--------------------------------------------------------------*/
COMMIT;

/*==============================================================
  BUSINESS INTERPRETATION

  - Subscribers must pass structural eligibility, charge filters,
    and model criteria to enter today's active campaign base
  - Retained subscribers remain in the target for up to 30 days
    from Last_Eligible_Date if they still pass valid-base checks
  - Current eligibility refreshes Last_Eligible_Date to today
  - Retained non-scored subscribers intentionally keep NULL offers
    so those cases can be analyzed separately

  TARGET OUTPUT:
    Dwh_Coe.Coe_Uc05_Scaleup_With_Off_Pr
==============================================================*/
