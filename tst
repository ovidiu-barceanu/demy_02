-- ============================================================
-- LOY-TOP-01 - CLIENT_PARTNER_ID - Eligibility
-- Description:
-- Validates that every CLIENT_PARTNER_ID present in the Loyalty view
-- is an eligible partner.
--
-- A partner is eligible when:
-- 1. It has at least one active ASSETTYPE = 'B' FKN with
--    GBM in 0-7 or 9-19.
-- 2. It has at least one active ASSETTYPE = 'B' FKN with
--    SEGMENT in ('GK Märkte', 'GK Region', 'FYRST', 'FK').
--
-- The GBM and SEGMENT conditions may be satisfied by different FKNs
-- belonging to the same PARTID.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

WITH fkn_base AS (
    SELECT
        CAST(PARTID AS STRING) AS partner_id,
        FKN,
        GBM,
        SEGMENT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_uat_fra.fkn_segmentation`
    WHERE CLOSED_FKN = FALSE
      AND ASSETTYPE = 'B'
),

eligible_partners AS (
    SELECT DISTINCT
        a.partner_id
    FROM fkn_base a
    WHERE (
        a.GBM BETWEEN 0 AND 7
        OR a.GBM BETWEEN 9 AND 19
    )
      AND EXISTS (
          SELECT 1
          FROM fkn_base b
          WHERE b.partner_id = a.partner_id
            AND b.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
      )
)

SELECT DISTINCT
    CAST(l.CLIENT_PARTNER_ID AS STRING) AS client_partner_id
FROM `db-uat-g8rw-mp-dap.dap_businessvault_loyalty_uat_fra.int_loyalty_denormalized_table_v1` l
LEFT JOIN eligible_partners e
    ON CAST(l.CLIENT_PARTNER_ID AS STRING) = e.partner_id
WHERE l.CLIENT_PARTNER_ID IS NOT NULL
  AND e.partner_id IS NULL;


-- ============================================================
-- LOY-TOP-01.1 - CLIENT_PARTNER_ID - Missing Eligible Partners
-- Description:
-- Validates the reverse direction:
-- every partner that satisfies the confirmed FKN eligibility
-- criteria is present as CLIENT_PARTNER_ID in the Loyalty view.
--
-- The GBM and SEGMENT conditions are evaluated at PARTID level
-- and may be satisfied by different FKNs.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

WITH fkn_base AS (
    SELECT
        CAST(PARTID AS STRING) AS partner_id,
        FKN,
        GBM,
        SEGMENT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_uat_fra.fkn_segmentation`
    WHERE CLOSED_FKN = FALSE
      AND ASSETTYPE = 'B'
),

eligible_partners AS (
    SELECT DISTINCT
        a.partner_id
    FROM fkn_base a
    WHERE (
        a.GBM BETWEEN 0 AND 7
        OR a.GBM BETWEEN 9 AND 19
    )
      AND EXISTS (
          SELECT 1
          FROM fkn_base b
          WHERE b.partner_id = a.partner_id
            AND b.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
      )
),

loyalty_partners AS (
    SELECT DISTINCT
        CAST(CLIENT_PARTNER_ID AS STRING) AS partner_id
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_loyalty_uat_fra.int_loyalty_denormalized_table_v1`
    WHERE CLIENT_PARTNER_ID IS NOT NULL
)

SELECT
    e.partner_id AS missing_client_partner_id
FROM eligible_partners e
LEFT JOIN loyalty_partners l
    ON e.partner_id = l.partner_id
WHERE l.partner_id IS NULL;


-- ============================================================
-- LOY-TOP-02 - CLIENT_PARTNER_ID - Not Null
-- Description:
-- Validates that CLIENT_PARTNER_ID is populated for every record
-- in the Loyalty view.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

SELECT *
FROM `db-uat-g8rw-mp-dap.dap_businessvault_loyalty_uat_fra.int_loyalty_denormalized_table_v1`
WHERE CLIENT_PARTNER_ID IS NULL;


-- ============================================================
-- LOY-TOP-02.1 - CLIENT_PARTNER_ID - Uniqueness
-- Description:
-- Validates that each CLIENT_PARTNER_ID occurs only once at the
-- top level of the Loyalty denormalized view.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

SELECT
    CLIENT_PARTNER_ID,
    COUNT(*) AS row_count
FROM `db-uat-g8rw-mp-dap.dap_businessvault_loyalty_uat_fra.int_loyalty_denormalized_table_v1`
WHERE CLIENT_PARTNER_ID IS NOT NULL
GROUP BY CLIENT_PARTNER_ID
HAVING COUNT(*) > 1;
