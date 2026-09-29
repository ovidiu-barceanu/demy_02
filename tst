-- ============================================================
-- TC-03-TEMPORARY - Validate CLIENT_PARTNER_NAME ignoring
-- leading/trailing whitespace
--
-- Checks that each CLIENT_PARTNER_NAME in Loyalty has at least
-- one matching PDOA Party record for the same partner.
--
-- TRIM is applied to ignore the known leading/trailing
-- whitespace issue in the Loyalty view.
--
-- Multiple PDOA records for the same partner are allowed.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

SELECT
    l.CLIENT_PARTNER_ID,
    l.CLIENT_PARTNER_NAME AS loyalty_value
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l

WHERE NOT EXISTS (
    SELECT 1
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    WHERE SAFE_CAST(p.identifier.id AS INT64) = l.CLIENT_PARTNER_ID
      AND p.meta_snapshot_context IS NOT NULL

      AND TRIM(l.CLIENT_PARTNER_NAME) = TRIM(
          REGEXP_REPLACE(
              CASE
                  WHEN p.payload.type = 'Organisation'
                      THEN p.payload.detail.legalName
                  ELSE CONCAT(
                      COALESCE(p.payload.detail.currentlyKnownAs.firstName, ''),
                      ' ',
                      COALESCE(p.payload.detail.currentlyKnownAs.lastName, '')
                  )
              END,
              r'\s+',
              ' '
          )
      )
);
