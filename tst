-- ============================================================
-- ORI-05 - Validate approved Product filter
-- Description:
-- Validates eligibility using BizBanking segment when PARTNERID
-- exists. When PARTNERID is missing, validates eligibility using
-- the approved Product filter from EXTREF.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id,
        s.segment
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
)

SELECT DISTINCT
    tgt.PARTNERID,
    tgt.EXTREF
FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all` tgt
LEFT JOIN bs_current bs
  ON SAFE_CAST(tgt.PARTNERID AS STRING) = bs.partner_id
WHERE
    (
        tgt.PARTNERID IS NOT NULL
        AND bs.partner_id IS NULL
    )
    OR
    (
        tgt.PARTNERID IS NULL
        AND (
            tgt.EXTREF IS NULL
            OR NOT REGEXP_CONTAINS(
                UPPER(tgt.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-[0-9]{1,2}-[A-Z0-9]{8}\s+[0-9]{6}-[0-9]{6}\s+[0-9]{8}-[0-9]$'
            )
            OR REGEXP_EXTRACT(
                UPPER(tgt.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
            ) NOT IN (
                '041','081','084','085','087','088',
                '141','160','181','431','485','570',
                '573','576','358','345','592','593'
            )
        )
    );


-- ============================================================
-- ORI-08 - Validate journeys without FKN are included
-- Description:
-- Identifies eligible journeys without FKN. Eligibility is
-- determined by BizBanking segment when PARTNERID exists.
-- Records returned provide evidence that no-FKN journeys are
-- present in the filtered Analytical target.
--
-- 0 rows = FAIL
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id,
        s.segment
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
      AND s.segment IN ('GK Region', 'GK Märkte', 'FYRST')
),

source_fkn AS (
    SELECT
        src.EXTREF,
        src.PARTNERID,
        COUNTIF(mcd.identifier.id IS NOT NULL) AS FKN_COUNT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_orinoco_uat_fra.orinoco_all` src

    JOIN bs_current bs
      ON SAFE_CAST(src.PARTNERID AS STRING) = bs.partner_id

    LEFT JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.pdoa_customer_association` ca
      ON SAFE_CAST(src.PARTNERID AS STRING) =
         SAFE_CAST(ca.identifier.id AS STRING)

    LEFT JOIN UNNEST(
        ca.payload.customerAssociationType.masterContractDetails
    ) AS mcd

    WHERE src.PARTNERID IS NOT NULL
      AND src.EXTREF IS NOT NULL
      AND TRIM(src.EXTREF) <> ''

    GROUP BY
        src.EXTREF,
        src.PARTNERID
)

SELECT DISTINCT
    src.PARTNERID,
    src.EXTREF
FROM source_fkn src
JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all` tgt
  ON src.EXTREF = tgt.EXTREF
WHERE src.FKN_COUNT = 0;


-- ============================================================
-- ORI-08.1 - Validate no-FKN journeys are not missing from target
-- Description:
-- Checks that eligible journeys without FKN are not missing
-- from the filtered BizBanking Analytical target. Eligibility
-- uses BizBanking segment when PARTNERID exists.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id,
        s.segment
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
      AND s.segment IN ('GK Region', 'GK Märkte', 'FYRST')
),

source_fkn AS (
    SELECT
        src.EXTREF,
        src.PARTNERID,
        COUNTIF(mcd.identifier.id IS NOT NULL) AS FKN_COUNT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_orinoco_uat_fra.orinoco_all` src

    JOIN bs_current bs
      ON SAFE_CAST(src.PARTNERID AS STRING) = bs.partner_id

    LEFT JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.pdoa_customer_association` ca
      ON SAFE_CAST(src.PARTNERID AS STRING) =
         SAFE_CAST(ca.identifier.id AS STRING)

    LEFT JOIN UNNEST(
        ca.payload.customerAssociationType.masterContractDetails
    ) AS mcd

    WHERE src.PARTNERID IS NOT NULL
      AND src.EXTREF IS NOT NULL
      AND TRIM(src.EXTREF) <> ''

    GROUP BY
        src.EXTREF,
        src.PARTNERID
),

eligible_without_fkn AS (
    SELECT
        PARTNERID,
        EXTREF
    FROM source_fkn
    WHERE FKN_COUNT = 0
)

SELECT
    src.PARTNERID,
    src.EXTREF
FROM eligible_without_fkn src
LEFT JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all` tgt
  ON src.EXTREF = tgt.EXTREF
WHERE tgt.EXTREF IS NULL;


-- ============================================================
-- ORI-10 - Validate eligible source journeys are included
-- Description:
-- Validates that eligible source journeys are available in the
-- Analytical target. When PARTNERID exists eligibility is based
-- on BizBanking segment. When PARTNERID is missing eligibility
-- is determined from EXTREF using the ticket filtering rules.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
      AND s.segment IN ('GK Region', 'GK Märkte', 'FYRST')
),

eligible_source AS (
    SELECT DISTINCT
        src.PARTNERID,
        src.EXTREF
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_orinoco_uat_fra.orinoco_all` src
    LEFT JOIN bs_current bs
      ON SAFE_CAST(src.PARTNERID AS STRING) = bs.partner_id
    WHERE
        (
            src.PARTNERID IS NOT NULL
            AND bs.partner_id IS NOT NULL
        )
        OR
        (
            src.PARTNERID IS NULL

            AND REGEXP_CONTAINS(
                UPPER(src.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-[0-9]{1,2}-[A-Z0-9]{8}\s+[0-9]{6}-[0-9]{6}\s+[0-9]{8}-[0-9]$'
            )

            AND REGEXP_EXTRACT(
                UPPER(src.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
            ) IN (
                '041','081','084','085','087','088',
                '141','160','181','431','485','570',
                '573','576','358','345','592','593'
            )

            AND (
                REGEXP_EXTRACT(
                    UPPER(src.EXTREF),
                    r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
                ) <> '431'

                OR REGEXP_EXTRACT(
                    UPPER(src.EXTREF),
                    r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-([0-9]{1,2})-'
                ) IN ('12','82')
            )
        )
),

target AS (
    SELECT DISTINCT EXTREF
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all`
    WHERE EXTREF IS NOT NULL
)

SELECT
    src.PARTNERID,
    src.EXTREF
FROM eligible_source src
WHERE NOT EXISTS (
    SELECT 1
    FROM target tgt
    WHERE tgt.EXTREF = src.EXTREF
);


-- ============================================================
-- ORI-13 - Validate CBPB approved Product filter
-- Description:
-- Validates CBPB eligibility using BizBanking segment when
-- PARTNERID exists. When PARTNERID is missing, validates
-- eligibility using the approved Product filter from EXTREF.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
      AND s.segment IN ('GK Region', 'GK Märkte', 'FYRST')
)

SELECT DISTINCT
    tgt.PARTNERID,
    tgt.EXTREF
FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all_cbpb` tgt
LEFT JOIN bs_current bs
  ON SAFE_CAST(tgt.PARTNERID AS STRING) = bs.partner_id
WHERE
    (
        tgt.PARTNERID IS NOT NULL
        AND bs.partner_id IS NULL
    )
    OR
    (
        tgt.PARTNERID IS NULL
        AND (
            tgt.EXTREF IS NULL
            OR NOT REGEXP_CONTAINS(
                UPPER(tgt.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-[0-9]{1,2}-[A-Z0-9]{8}\s+[0-9]{6}-[0-9]{6}\s+[0-9]{8}-[0-9]$'
            )
            OR REGEXP_EXTRACT(
                UPPER(tgt.EXTREF),
                r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
            ) NOT IN (
                '041','081','084','085','087','088',
                '141','160','181','431','485','570',
                '573','576','358','345','592','593'
            )
        )
    );


-- ============================================================
-- ORI-14 - Validate CBPB journeys without Partner ID
-- Description:
-- Validates that CBPB journeys are not excluded because
-- PARTNERID is missing. For these records eligibility is
-- determined from EXTREF using the ticket filtering rules.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

SELECT DISTINCT
    PARTNERID,
    EXTREF
FROM `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all_cbpb`
WHERE PARTNERID IS NULL
  AND (
      EXTREF IS NULL

      OR NOT REGEXP_CONTAINS(
          UPPER(EXTREF),
          r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-[0-9]{1,2}-[A-Z0-9]{8}\s+[0-9]{6}-[0-9]{6}\s+[0-9]{8}-[0-9]$'
      )

      OR REGEXP_EXTRACT(
          UPPER(EXTREF),
          r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
      ) NOT IN (
          '041','081','084','085','087','088',
          '141','160','181','431','485','570',
          '573','576','358','345','592','593'
      )

      OR (
          REGEXP_EXTRACT(
              UPPER(EXTREF),
              r'^[A-Z0-9]{2,}DEOPRA\s+([0-9]{3})-'
          ) = '431'

          AND REGEXP_EXTRACT(
              UPPER(EXTREF),
              r'^[A-Z0-9]{2,}DEOPRA\s+[0-9]{3}-([0-9]{1,2})-'
          ) NOT IN ('12','82')
      )
  );


-- ============================================================
-- ORI-15 - Validate CBPB journeys without FKN
-- Description:
-- Validates that eligible CBPB journeys are not excluded
-- because FKN is missing. Eligibility for records with a
-- PARTNERID is determined using the BizBanking segment.
--
-- 0 rows = PASS
-- Status =
-- ============================================================

WITH bs_current AS (
    SELECT DISTINCT
        CAST(l.partner_id AS STRING) AS partner_id
    FROM `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_l` l
    JOIN `db-uat-g8rw-mp-dap.dap_rawvault_bluespace_uat_fra.raw_bluespace__crm_s` s
      ON l.customer_id = s.customer_id
    WHERE s.record_valid_to = '9999-12-30 00:00:00 UTC'
      AND l.partner_id IS NOT NULL
      AND s.segment IN ('GK Region', 'GK Märkte', 'FYRST')
),

source_fkn AS (
    SELECT
        src.EXTREF,
        src.PARTNERID,
        COUNTIF(mcd.identifier.id IS NOT NULL) AS FKN_COUNT
    FROM `db-uat-g8rw-mp-dap.dap_businessvault_orinoco_uat_fra.orinoco_all_cbpb` src

    JOIN bs_current bs
      ON SAFE_CAST(src.PARTNERID AS STRING) = bs.partner_id

    LEFT JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.pdoa_customer_association` ca
      ON SAFE_CAST(src.PARTNERID AS STRING) =
         SAFE_CAST(ca.identifier.id AS STRING)

    LEFT JOIN UNNEST(
        ca.payload.customerAssociationType.masterContractDetails
    ) AS mcd

    WHERE src.PARTNERID IS NOT NULL
      AND src.EXTREF IS NOT NULL

    GROUP BY
        src.EXTREF,
        src.PARTNERID
),

eligible_without_fkn AS (
    SELECT
        PARTNERID,
        EXTREF
    FROM source_fkn
    WHERE FKN_COUNT = 0
)

SELECT
    src.PARTNERID,
    src.EXTREF
FROM eligible_without_fkn src
LEFT JOIN `db-uat-g8rw-mp-dap.dap_businessvault_analytical_bizbanking_uat_fra.orinoco_all_cbpb` tgt
  ON src.EXTREF = tgt.EXTREF
WHERE tgt.EXTREF IS NULL;
