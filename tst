-- ============================================================
-- LOY-TOP-01 - Validate CLIENT_PARTNER_ID against PDOA
-- Description:
-- Validates that every CLIENT_PARTNER_ID present in Loyalty
-- exists as a PARTY_ID in PDOA.
--
-- Expected result: 0 rows = PASSED
-- Status =
-- ============================================================

SELECT DISTINCT
    CAST(l.CLIENT_PARTNER_ID AS STRING) AS CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    ON CAST(p.PARTY_ID AS STRING) = CAST(l.CLIENT_PARTNER_ID AS STRING)
WHERE p.PARTY_ID IS NULL;


-- ============================================================
-- LOY-TOP-02 - Validate CLIENT_PARTNER_ID uniqueness
-- Description:
-- Validates that CLIENT_PARTNER_ID is unique at the top level
-- of the Loyalty view.
--
-- Expected result: 0 rows = PASSED
-- Status =
-- ============================================================

SELECT
    CLIENT_PARTNER_ID,
    COUNT(*) AS RECORD_COUNT
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1`
GROUP BY CLIENT_PARTNER_ID
HAVING COUNT(*) > 1;


-- ============================================================
-- LOY-TOP-02.1 - Validate eligible CLIENT_PARTNER_ID completeness
-- Description:
-- Validates that every partner eligible for Loyalty according
-- to the FKN eligibility rules exists in the Loyalty view.
--
-- Partner eligibility requires:
-- 1. At least one active ASSETTYPE = 'B' FKN with
--    GBM 0-7 or 9-19.
-- 2. At least one active ASSETTYPE = 'B' FKN with
--    SEGMENT in ('GK Märkte', 'GK Region', 'FYRST', 'FK').
--
-- The GBM and SEGMENT conditions are evaluated at PARTID level
-- and may be fulfilled by different FKNs.
--
-- Expected result: 0 rows = PASSED
-- Status =
-- ============================================================

WITH active_fkn AS (
    SELECT
        CAST(PARTID AS STRING) AS PARTID,
        FKN,
        GBM,
        SEGMENT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_uat_fra.fkn_segmentation`
    WHERE CLOSED_FKN = FALSE
      AND ASSETTYPE = 'B'
),

eligible_partners AS (
    SELECT DISTINCT
        a.PARTID
    FROM active_fkn a
    WHERE EXISTS (
        SELECT 1
        FROM active_fkn gbm
        WHERE gbm.PARTID = a.PARTID
          AND (
                gbm.GBM BETWEEN 0 AND 7
                OR gbm.GBM BETWEEN 9 AND 19
              )
    )
      AND EXISTS (
        SELECT 1
        FROM active_fkn seg
        WHERE seg.PARTID = a.PARTID
          AND seg.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
    )
)

SELECT
    e.PARTID AS CLIENT_PARTNER_ID
FROM eligible_partners e
LEFT JOIN `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
    ON CAST(l.CLIENT_PARTNER_ID AS STRING) = e.PARTID
WHERE l.CLIENT_PARTNER_ID IS NULL;


-- ============================================================
-- LOY-TOP-02.2 - Validate Loyalty clients meet FKN eligibility
-- Description:
-- Reverse validation of LOY-TOP-02.1.
-- Validates that every CLIENT_PARTNER_ID present in Loyalty
-- qualifies according to the confirmed partner-level FKN rules.
--
-- Expected result: 0 rows = PASSED
-- Status =
-- ============================================================

WITH active_fkn AS (
    SELECT
        CAST(PARTID AS STRING) AS PARTID,
        FKN,
        GBM,
        SEGMENT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_uat_fra.fkn_segmentation`
    WHERE CLOSED_FKN = FALSE
      AND ASSETTYPE = 'B'
),

eligible_partners AS (
    SELECT DISTINCT
        a.PARTID
    FROM active_fkn a
    WHERE EXISTS (
        SELECT 1
        FROM active_fkn gbm
        WHERE gbm.PARTID = a.PARTID
          AND (
                gbm.GBM BETWEEN 0 AND 7
                OR gbm.GBM BETWEEN 9 AND 19
              )
    )
      AND EXISTS (
        SELECT 1
        FROM active_fkn seg
        WHERE seg.PARTID = a.PARTID
          AND seg.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
    )
)

SELECT DISTINCT
    CAST(l.CLIENT_PARTNER_ID AS STRING) AS CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN eligible_partners e
    ON e.PARTID = CAST(l.CLIENT_PARTNER_ID AS STRING)
WHERE e.PARTID IS NULL;
