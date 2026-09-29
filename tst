-- ============================================================
-- TC-03-DIAGNOSTIC - CLIENT_PARTNER_NAME
--
-- Diagnostic for TC-03-TEMPORARY failures.
--
-- Returns only CLIENT_PARTNER_IDs where no PDOA Party record
-- matches the Loyalty name after TRIM.
--
-- For each failed partner, shows all available PDOA candidate
-- names for comparison.
--
-- Diagnostic query
-- Status =
-- ============================================================

WITH failed_partners AS (
    SELECT
        l.CLIENT_PARTNER_ID,
        l.CLIENT_PARTNER_CLASS,
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
    )
)

SELECT
    f.CLIENT_PARTNER_ID,
    f.CLIENT_PARTNER_CLASS,
    f.loyalty_value,

    p.payload.type AS pdoa_type,
    p.payload.detail.legalName AS legal_name,
    p.payload.detail.currentlyKnownAs.firstName AS first_name,
    p.payload.detail.currentlyKnownAs.lastName AS last_name,

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
    ) AS pdoa_name,

    TRIM(f.loyalty_value) AS trimmed_loyalty_value,

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
    ) AS trimmed_pdoa_name

FROM failed_partners f

LEFT JOIN `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    ON SAFE_CAST(p.identifier.id AS INT64) = f.CLIENT_PARTNER_ID
   AND p.meta_snapshot_context IS NOT NULL

ORDER BY
    f.CLIENT_PARTNER_ID,
    pdoa_name;
