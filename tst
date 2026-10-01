-- ============================================================
-- TST 01 - CLIENT_PARTNER_ID - Validate against PDOA
-- Description:
-- Validates that every CLIENT_PARTNER_ID present in the Loyalty view
-- exists in PDOA Party as identifier.id.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

SELECT DISTINCT
    l.CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    ON CAST(l.CLIENT_PARTNER_ID AS STRING) = CAST(p.identifier.id AS STRING)
WHERE p.identifier.id IS NULL;


-- ============================================================
-- TST 02 - CLIENT_PARTNER_ID - Uniqueness
-- Description:
-- Validates that CLIENT_PARTNER_ID occurs only once at the top level
-- of the Loyalty view.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

SELECT
    CLIENT_PARTNER_ID,
    COUNT(*) AS RECORD_COUNT
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1`
GROUP BY CLIENT_PARTNER_ID
HAVING COUNT(*) > 1;


-- ============================================================
-- TST 02.1 - CLIENT_PARTNER_ID - Eligible partners missing from Loyalty
-- Description:
-- Validates that every partner eligible according to the confirmed
-- FKN eligibility rules is present as CLIENT_PARTNER_ID in Loyalty.
--
-- Eligible FKN scope:
--   CLOSED_FKN = FALSE
--   ASSETTYPE = 'B'
--
-- At PARTID level BOTH conditions must exist:
--   A) At least one active FKN with GBM 0-7 or 9-19
--      (GBM 8 excluded)
--   B) At least one active FKN with SEGMENT IN (1,11,21,71)
--
-- Segment mapping:
--   1  = FK
--   11 = GK Märkte
--   21 = GK Region
--   71 = FYRST
--
-- The GBM and SEGMENT conditions may be fulfilled by different FKNs
-- belonging to the same PARTID.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

WITH active_fkn AS (
    SELECT
        PARTID,
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
          AND s.SEGMENT IN (1, 11, 21, 71)
    )
)

SELECT
    e.PARTID AS CLIENT_PARTNER_ID
FROM eligible_partners e
LEFT JOIN `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
    ON SAFE_CAST(l.CLIENT_PARTNER_ID AS INT64) = e.PARTID
WHERE l.CLIENT_PARTNER_ID IS NULL;


-- ============================================================
-- TST 02.2 - CLIENT_PARTNER_ID - No ineligible partners in Loyalty
-- Description:
-- Validates that every CLIENT_PARTNER_ID present in the Loyalty view
-- satisfies the confirmed FKN eligibility rules.
--
-- Eligible FKN scope:
--   CLOSED_FKN = FALSE
--   ASSETTYPE = 'B'
--
-- At PARTID level BOTH conditions must exist:
--   A) At least one active FKN with GBM 0-7 or 9-19
--      (GBM 8 excluded)
--   B) At least one active FKN with SEGMENT IN (1,11,21,71)
--
-- Segment mapping:
--   1  = FK
--   11 = GK Märkte
--   21 = GK Region
--   71 = FYRST
--
-- The GBM and SEGMENT conditions may be fulfilled by different FKNs
-- belonging to the same PARTID.
--
-- Expected result: 0 rows = Passed
-- Status =
-- ============================================================

WITH active_fkn AS (
    SELECT
        PARTID,
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
          AND s.SEGMENT IN (1, 11, 21, 71)
    )
)

SELECT DISTINCT
    l.CLIENT_PARTNER_ID
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
LEFT JOIN eligible_partners e
    ON e.PARTID = SAFE_CAST(l.CLIENT_PARTNER_ID AS INT64)
WHERE e.PARTID IS NULL;
