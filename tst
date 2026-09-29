-- ============================================================
-- TC-03-DIAGNOSTIC - CLIENT_PARTNER_NAME
--
-- Uses the same failure condition as TC-03-TEMPORARY.
-- Returns only the records that fail TC-03-TEMPORARY.
--
-- Shows all PDOA candidate names for the failed partner
-- in one field, without creating multiple result rows.
--
-- Diagnostic query
-- Status =
-- ============================================================

SELECT
    l.CLIENT_PARTNER_ID,
    l.CLIENT_PARTNER_CLASS,
    l.CLIENT_PARTNER_NAME AS loyalty_value,
    TRIM(l.CLIENT_PARTNER_NAME) AS trimmed_loyalty_value,

    ARRAY(
        SELECT DISTINCT TRIM(
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
        FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
        WHERE SAFE_CAST(p.identifier.id AS INT64) = l.CLIENT_PARTNER_ID
          AND p.meta_snapshot_context IS NOT NULL
    ) AS pdoa_names

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
)

ORDER BY l.CLIENT_PARTNER_ID;
