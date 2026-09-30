-- ============================================================
-- LOY-TOP-01 - Validate CLIENT_PARTNER_ID against PDOA
-- Description:
-- Validates that every CLIENT_PARTNER_ID in the Loyalty view
-- exists in PDOA Party using identifier.id.
--
-- Expected result: 0 rows = PASSED
-- Status =
-- ============================================================

SELECT DISTINCT
    l.CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    ON CAST(l.CLIENT_PARTNER_ID AS STRING) = CAST(p.identifier.id AS STRING)
WHERE p.identifier.id IS NULL;


-- ============================================================
-- LOY-TOP-02 - Validate CLIENT_PARTNER_ID uniqueness
-- Description:
-- Validates that CLIENT_PARTNER_ID occurs only once at the
-- top level of the Loyalty view.
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
-- to the confirmed FKN eligibility rules exists in the
-- Loyalty view.
--
-- Eligibility is evaluated at PARTID level.
--
-- A partner qualifies when:
-- - at least one active ASSETTYPE = 'B' FKN has
--   GBM between 0-7 or 9-19
-- AND
-- - at least one active ASSETTYPE = 'B' FKN has
--   SEGMENT in ('GK Märkte', 'GK Region', 'FYRST', 'FK')
--
-- The two conditions may be fulfilled by different FKNs
-- belonging to the same PARTID.
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
        FROM active_fkn g
        WHERE g.PARTID = a.PARTID
          AND (
              g.GBM BETWEEN 0 AND 7
              OR g.GBM BETWEEN 9 AND 19
          )
    )
    AND EXISTS (
        SELECT 1
        FROM active_fkn s
        WHERE s.PARTID = a.PARTID
          AND s.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
    )
)

SELECT
    e.PARTID AS CLIENT_PARTNER_ID
FROM eligible_partners e
LEFT JOIN `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
    ON CAST(l.CLIENT_PARTNER_ID AS STRING) = e.PARTID
WHERE l.CLIENT_PARTNER_ID IS NULL;


-- ============================================================
-- LOY-TOP-02.2 - Validate Loyalty CLIENT_PARTNER_ID eligibility
-- Description:
-- Reverse validation of LOY-TOP-02.1.
-- Validates that every CLIENT_PARTNER_ID present in Loyalty
-- satisfies the confirmed partner-level FKN eligibility rules.
--
-- Eligibility is evaluated at PARTID level and the GBM and
-- SEGMENT conditions may be fulfilled by different FKNs.
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
        FROM active_fkn g
        WHERE g.PARTID = a.PARTID
          AND (
              g.GBM BETWEEN 0 AND 7
              OR g.GBM BETWEEN 9 AND 19
          )
    )
    AND EXISTS (
        SELECT 1
        FROM active_fkn s
        WHERE s.PARTID = a.PARTID
          AND s.SEGMENT IN ('GK Märkte', 'GK Region', 'FYRST', 'FK')
    )
)

SELECT DISTINCT
    l.CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN eligible_partners e
    ON e.PARTID = CAST(l.CLIENT_PARTNER_ID AS STRING)
WHERE e.PARTID IS NULL;
