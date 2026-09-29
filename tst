SELECT
    CLIENT_PARTNER_ID,
    CONCAT('[', CLIENT_PARTNER_NAME, ']') AS loyalty_value,
    LENGTH(CLIENT_PARTNER_NAME) AS loyalty_length,
    LENGTH(TRIM(CLIENT_PARTNER_NAME)) AS trimmed_length
FROM `db-uat-g8rw-mp-dap.dap_shared_views_loyalty_uat_fra.loyalty__denormalized_view_v1`
WHERE CLIENT_PARTNER_ID = 5225343000400;
