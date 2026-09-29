-- ============================================================
-- TC-03 - Diagnostic CLIENT_PARTNER_NAME
-- Show sample mismatches
-- ============================================================

SELECT
    l.CLIENT_PARTNER_ID,
    l.CLIENT_PARTNER_CLASS,
    l.CLIENT_PARTNER_NAME AS loyalty_value,

    p.payload.type AS pdoa_type,
    p.payload.detail.legalName AS legal_name,
    p.payload.detail.currentlyKnownAs.firstName AS first_name,
    p.payload.detail.currentlyKnownAs.lastName AS last_name,

    CASE
        WHEN p.payload.type = 'Organisation'
            THEN p.payload.detail.legalName
        ELSE CONCAT(
            COALESCE(p.payload.detail.currentlyKnownAs.firstName, ''),
            ' ',
            COALESCE(p.payload.detail.currentlyKnownAs.lastName, '')
        )
    END AS calculated_source_value

FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1` l

JOIN `db-uat-g8rw-mp-dap.dap_rawvault_uat_fra.pdoa_party` p
    ON l.CLIENT_PARTNER_ID = SAFE_CAST(p.identifier.id AS INT64)
    AND p.meta_snapshot_context IS NOT NULL

WHERE l.CLIENT_PARTNER_NAME IS DISTINCT FROM
    CASE
        WHEN p.payload.type = 'Organisation'
            THEN p.payload.detail.legalName
        ELSE CONCAT(
            COALESCE(p.payload.detail.currentlyKnownAs.firstName, ''),
            ' ',
            COALESCE(p.payload.detail.currentlyKnownAs.lastName, '')
        )
    END

LIMIT 20;
