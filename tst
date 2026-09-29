-- ============================================================
-- TC-03-DIAGNOSTIC - CLIENT_PARTNER_NAME
--
-- Same scope as TC-03-TEMPORARY.
-- Shows only failed Loyalty records.
--
-- Shows whether NULL exists in PDOA and all non-NULL
-- PDOA candidate names for the same CLIENT_PARTNER_ID.
--
-- Diagnostic query
-- Status =
-- ============================================================

SELECT
    l.CLIENT_PARTNER_ID,
    l.CLIENT_PARTNER_CLASS,
    l.CLIENT_PARTNER_NAME AS loyalty_value,
    TRIM(l.CLIENT_PARTNER_NAME) AS trimmed_loyalty_value,

    -- Does PDOA contain a NULL name for this partner?
    EXISTS (
        SELECT 1
        FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
        WHERE SAFE_CAST(p.identifier.id AS INT64) = l.CLIENT_PARTNER_ID
          AND p.meta_snapshot_context IS NOT NULL
          AND (
              CASE
                  WHEN p.payload.type = 'Organisation'
                      THEN p.payload.detail.legalName
                  ELSE CONCAT(
                      COALESCE(p.payload.detail.currentlyKnownAs.firstName, ''),
                      ' ',
                      COALESCE(p.payload.detail.currentlyKnownAs.lastName, '')
                  )
              END
          ) IS NULL
    ) AS pdoa_has_null_name,

    -- Non-NULL names available in PDOA
    ARRAY(
        SELECT DISTINCT source_name
        FROM (
            SELECT
                TRIM(
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
                ) AS source_name
            FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
            WHERE SAFE_CAST(p.identifier.id AS INT64) = l.CLIENT_PARTNER_ID
              AND p.meta_snapshot_context IS NOT NULL
        )
        WHERE source_name IS NOT NULL
    ) AS pdoa_names

FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l

WHERE NOT EXISTS (
    SELECT 1
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    WHERE SAFE_CAST(p.identifier.id AS INT64) = l.CLIENT_PARTNER_ID
      AND p.meta_snapshot_context IS NOT NULL

      AND (
          -- Both are NULL
          (
              l.CLIENT_PARTNER_NAME IS NULL
              AND
              CASE
                  WHEN p.payload.type = 'Organisation'
                      THEN p.payload.detail.legalName
                  ELSE CONCAT(
                      COALESCE(p.payload.detail.currentlyKnownAs.firstName, ''),
                      ' ',
                      COALESCE(p.payload.detail.currentlyKnownAs.lastName, '')
                  )
              END IS NULL
          )

          OR

          -- Both have values and match after TRIM
          TRIM(l.CLIENT_PARTNER_NAME) = TRIM(
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
)

ORDER BY l.CLIENT_PARTNER_ID;
