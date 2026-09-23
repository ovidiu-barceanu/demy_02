-- ============================================================
-- ORI-06 - Validate Product 431 Channel/Type combinations
-- Description:
-- Returns Product 431 journeys where Channel/Type is not one
-- of the allowed combinations: 12 or 82.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

SELECT DISTINCT
    PARTNERID,
    EXTREF
FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all`
WHERE REGEXP_CONTAINS(
        UPPER(EXTREF),
        r'^[A-Z0-9]{2,}DEOPRA\s+431-'
      )
  AND NOT REGEXP_CONTAINS(
        UPPER(EXTREF),
        r'^[A-Z0-9]{2,}DEOPRA\s+431-(12|82)-'
      );
