-- ============================================================
-- ORI-08 - Validate journeys without FKN are included
-- Description:
-- Checks that eligible OPRA journeys without FKN are present
-- in the filtered BizBanking Analytical target.
--
-- Records returned = PASS
-- 0 rows = FAIL
-- Status =
-- ============================================================

WITH eligible_source AS (
    SELECT DISTINCT
        PARTNERID,
        EXTREF
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_orinoco_uat_fra.orinoco_all`
    WHERE PARTNERID IS NOT NULL
      AND EXTREF IS NOT NULL
      AND TRIM(EXTREF) <> ''

      -- Valid DE OPRA ID
      AND REGEXP_CONTAINS(
            UPPER(EXTREF),
            r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-[0-9]{1,2}-[A-Z0-9]{8}\s+[0-9]{6}-[0-9]{6}\s+[0-9]{8}-[0-9]$'
          )

      -- Approved products
      AND REGEXP_EXTRACT(
            UPPER(EXTREF),
            r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
          ) IN (
            '041','081','084','085','087','088',
            '141','160','181','431','485','570',
            '573','576','358','345','592','593'
          )

      -- Product 431 only with Channel/Type 12 or 82
      AND (
            REGEXP_EXTRACT(
                UPPER(EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
            ) <> '431'
            OR
            REGEXP_EXTRACT(
                UPPER(EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-([0-9]{1,2})-'
            ) IN ('12','82')
          )
),

source_partners AS (
    SELECT DISTINCT
        SAFE_CAST(PARTNERID AS STRING) AS PARTNERID
    FROM eligible_source
),

partners_with_fkn AS (
    SELECT DISTINCT
        SAFE_CAST(ca.identifier.id AS STRING) AS PARTNERID
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.pdoa_customer_association` ca

    INNER JOIN source_partners src
        ON SAFE_CAST(ca.identifier.id AS STRING) = src.PARTNERID

    CROSS JOIN UNNEST(
        ca.payload.customerAssociationType.masterContractDetails
    ) AS mcd

    WHERE mcd.identifier.id IS NOT NULL
),

without_fkn AS (
    SELECT
        src.PARTNERID,
        src.EXTREF
    FROM eligible_source src

    LEFT JOIN partners_with_fkn f
        ON SAFE_CAST(src.PARTNERID AS STRING) = f.PARTNERID

    WHERE f.PARTNERID IS NULL
)

SELECT DISTINCT
    tgt.PARTNERID,
    tgt.EXTREF
FROM without_fkn src

INNER JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all` tgt
    ON src.EXTREF = tgt.EXTREF;
