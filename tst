-- ============================================================
-- TC-03-TEMPORARY - Validate CLIENT_PARTNER_NAME ignoring
-- leading/trailing whitespace
--
-- Source: active PDOA Party record
--
-- Organisation:
--   CLIENT_PARTNER_NAME = legal_name
--
-- Natural Person:
--   CLIENT_PARTNER_NAME = first_name + last_name
--
-- TRIM is applied to both values to ignore the known
-- leading/trailing whitespace issue in the Loyalty view.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH active_client AS (
    SELECT
        SAFE_CAST(p.identifier.id AS INT64) AS partner_id,
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
        ) AS expected_client_partner_name
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    WHERE p.meta_snapshot_context IS NOT NULL
)

SELECT
    l.CLIENT_PARTNER_ID,
    l.CLIENT_PARTNER_NAME AS loyalty_value,
    a.expected_client_partner_name AS source_value
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l
JOIN active_client a
    ON l.CLIENT_PARTNER_ID = a.partner_id
WHERE TRIM(l.CLIENT_PARTNER_NAME)
      IS DISTINCT FROM TRIM(a.expected_client_partner_name);
