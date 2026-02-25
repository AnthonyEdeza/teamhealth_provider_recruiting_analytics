USE TeamHealthProjectDB;

/* ============================================================
   File: 40_fact_quality_stability.sql

   Purpose:
     Measure quality and stability of recruiting outcomes by source.
     This focuses on retention signals (early attrition) and offer
     acceptance/decline behavior.

   Business Questions Supported:
     - Which sources deliver hires that stick (early attrition <= 90 days)?
     - Which sources have higher offer decline rates?
     - What reasons are driving offer declines?
     - How do agency vs non-agency sources compare on stability?

   Grain:
     1) dbo.fact_quality_stability
        One row per month_start_date x source_id

     2) dbo.fact_offer_decline_reasons
        One row per month_start_date x source_id x decline_reason

   Notes / Assumptions:
     - Hires are attributed to source based on the application tied to HRIS hire.
     - Offers are attributed to source based on the application tied to the offer.
     - Month is based on:
         hires: hire start_date month
         offers: offer_date month
     - source_id is normalized to 'UNKNOWN' when missing to preserve PK integrity.
   ============================================================ */

IF OBJECT_ID('dbo.fact_offer_decline_reasons', 'U') IS NOT NULL
    DROP TABLE dbo.fact_offer_decline_reasons;

IF OBJECT_ID('dbo.fact_quality_stability', 'U') IS NOT NULL
    DROP TABLE dbo.fact_quality_stability;

/* ============================================================
   Table 1: Monthly quality + stability KPIs by source
   ============================================================ */

CREATE TABLE dbo.fact_quality_stability
(
    month_start_date              DATE          NOT NULL,
    source_id                     NVARCHAR(50)  NOT NULL DEFAULT 'UNKNOWN',

    -- Source attributes (for slicing in Power BI)
    source_type                   NVARCHAR(100) NULL,
    channel                       NVARCHAR(100) NULL,
    is_paid                       BIT           NULL,

    -- Volume
    hires                          INT          NOT NULL,
    early_attrition_hires_90d      INT          NOT NULL,
    early_attrition_rate_90d       DECIMAL(9,4) NULL,

    offers                         INT          NOT NULL,
    declined_offers                INT          NOT NULL,
    offer_decline_rate             DECIMAL(9,4) NULL,

    -- Optional quality proxy if present
    avg_performance_rating_6mo     DECIMAL(9,4) NULL,

    created_ts                    DATETIME2     NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT PK_fact_quality_stability
        PRIMARY KEY (month_start_date, source_id)
);

/* ============================================================
   Table 2: Decline reasons by month/source (for ranked visuals)
   ============================================================ */

CREATE TABLE dbo.fact_offer_decline_reasons
(
    month_start_date              DATE          NOT NULL,
    source_id                     NVARCHAR(50)  NOT NULL DEFAULT 'UNKNOWN',
    decline_reason                NVARCHAR(200) NOT NULL DEFAULT 'UNKNOWN',

    declined_offers               INT           NOT NULL,

    created_ts                    DATETIME2     NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT PK_fact_offer_decline_reasons
        PRIMARY KEY (month_start_date, source_id, decline_reason)
);

/* ============================================================
   Step 1: Monthly hires by source (stability signal)
   ============================================================ */

WITH hires_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(fh.start_date), MONTH(fh.start_date), 1)         AS month_start_date,
        ISNULL(fa.source_id, 'UNKNOWN')                                     AS source_id,

        COUNT(*)                                                            AS hires,
        SUM(CASE WHEN fh.early_attrition_90d_flag = 1 THEN 1 ELSE 0 END)    AS early_attrition_hires_90d,
        AVG(CAST(fh.performance_rating_6mo AS DECIMAL(9,4)))                AS avg_performance_rating_6mo
    FROM dbo.fact_hire_hris fh
    JOIN dbo.fact_application fa
        ON fh.application_id = fa.application_id
    WHERE fh.start_date IS NOT NULL
    GROUP BY
        DATEFROMPARTS(YEAR(fh.start_date), MONTH(fh.start_date), 1),
        ISNULL(fa.source_id, 'UNKNOWN')
),

/* ============================================================
   Step 2: Monthly offers by source (accept/decline behavior)
   ============================================================ */

offers_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(fo.offer_date), MONTH(fo.offer_date), 1)     AS month_start_date,
        ISNULL(fa.source_id, 'UNKNOWN')                                 AS source_id,

        COUNT(*)                                                        AS offers,
        SUM(CASE WHEN fo.offer_status = 'Declined' THEN 1 ELSE 0 END)   AS declined_offers
    FROM dbo.fact_offer fo
    JOIN dbo.fact_application fa
        ON fo.application_id = fa.application_id
    WHERE fo.offer_date IS NOT NULL
    GROUP BY
        DATEFROMPARTS(YEAR(fo.offer_date), MONTH(fo.offer_date), 1),
        ISNULL(fa.source_id, 'UNKNOWN')
),

/* ============================================================
   Step 3: Create a month/source spine so we don't lose rows
           when a source has hires but no offers (or vice versa)
   ============================================================ */

month_source_spine AS
(
    SELECT 
        month_start_date,
        source_id
    FROM hires_monthly
    UNION
    SELECT 
        month_start_date,
        source_id
    FROM offers_monthly
)

INSERT INTO dbo.fact_quality_stability
(
    month_start_date,
    source_id,
    source_type,
    channel,
    is_paid,
    hires,
    early_attrition_hires_90d,
    early_attrition_rate_90d,
    offers,
    declined_offers,
    offer_decline_rate,
    avg_performance_rating_6mo
)
SELECT

    ms.month_start_date,
    ms.source_id,

    ds.source_type,
    ds.channel,
    ds.is_paid,

    ISNULL(h.hires, 0)                                          AS hires,
    ISNULL(h.early_attrition_hires_90d, 0)                      AS early_attrition_hires_90d,

    CASE
        WHEN ISNULL(h.hires, 0) > 0
            THEN CAST(ISNULL(h.early_attrition_hires_90d, 0) AS DECIMAL(9,4))
                 / CAST(h.hires AS DECIMAL(9,4))
        ELSE NULL
    END AS early_attrition_rate_90d,

    ISNULL(o.offers, 0)                                         AS offers,
    ISNULL(o.declined_offers, 0)                                AS declined_offers,

    CASE
        WHEN ISNULL(o.offers, 0) > 0
            THEN CAST(ISNULL(o.declined_offers, 0) AS DECIMAL(9,4))
                 / CAST(o.offers AS DECIMAL(9,4))
        ELSE NULL
    END AS offer_decline_rate,

    h.avg_performance_rating_6mo

FROM month_source_spine ms
LEFT JOIN hires_monthly h
    ON ms.month_start_date = h.month_start_date
   AND ms.source_id = h.source_id
LEFT JOIN offers_monthly o
    ON ms.month_start_date = o.month_start_date
   AND ms.source_id = o.source_id
LEFT JOIN dbo.dim_source ds
    ON ms.source_id = ds.source_id;

/* ============================================================
   Step 4: Decline reason mix (monthly by source)
   ============================================================ */

INSERT INTO dbo.fact_offer_decline_reasons
(
    month_start_date,
    source_id,
    decline_reason,
    declined_offers
)
SELECT
    DATEFROMPARTS(YEAR(fo.offer_date), MONTH(fo.offer_date), 1)     AS month_start_date,
    ISNULL(fa.source_id, 'UNKNOWN')                                 AS source_id,
    ISNULL(NULLIF(LTRIM(RTRIM(fo.decline_reason)), ''), 'UNKNOWN')  AS decline_reason,
    COUNT(*)                                                        AS declined_offers
FROM dbo.fact_offer fo
JOIN dbo.fact_application fa
    ON fo.application_id = fa.application_id
WHERE fo.offer_date IS NOT NULL
  AND fo.offer_status = 'Declined'
GROUP BY
    DATEFROMPARTS(YEAR(fo.offer_date), MONTH(fo.offer_date), 1),
    ISNULL(fa.source_id, 'UNKNOWN'),
    ISNULL(NULLIF(LTRIM(RTRIM(fo.decline_reason)), ''), 'UNKNOWN');

/* ============================================================
   Basic validation outputs
   ============================================================ */

SELECT 
    COUNT(*) AS row_count
FROM dbo.fact_quality_stability;

SELECT 
    TOP (25) *
FROM dbo.fact_quality_stability
ORDER BY 
    month_start_date DESC,
    hires DESC,
    offers DESC;

SELECT TOP (25)
    month_start_date, source_id, decline_reason, declined_offers
FROM dbo.fact_offer_decline_reasons
ORDER BY 
    month_start_date DESC, 
    declined_offers DESC;



