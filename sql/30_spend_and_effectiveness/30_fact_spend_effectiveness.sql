USE TeamHealthProjectDB;

/* ============================================================
   File: 30_fact_spend_effectiveness.sql

   Purpose:
     Evaluate sourcing and campaign effectiveness by linking
     marketing spend to recruiting outcomes.

   Business Questions Supported:
     - Which sources generate hires?
     - What is cost per application?
     - What is cost per hire?
     - How do paid vs non-paid channels compare?

   Grain:
     One row per month_start_date × source_id × campaign_id

   Notes:
     - Uses first-touch attribution based on application source_id.
     - Monthly aggregation aligns with leadership reporting cadence.
     - This table prioritizes transparency over advanced attribution logic.
   ============================================================ */

IF OBJECT_ID('dbo.fact_spend_effectiveness', 'U') IS NOT NULL
    DROP TABLE dbo.fact_spend_effectiveness;

CREATE TABLE dbo.fact_spend_effectiveness
(
    month_start_date         DATE          NOT NULL,
    source_id                NVARCHAR(50)  NOT NULL DEFAULT 'UNKNOWN',
    campaign_id              NVARCHAR(50)  NOT NULL DEFAULT 'UNKNOWN',

    total_impressions        INT           NULL,
    total_clicks             INT           NULL,
    total_apply_starts       INT           NULL,
    total_applications       INT           NULL,
    total_spend_usd          DECIMAL(18,2) NULL,

    total_hires              INT           NULL,
    total_offers             INT           NULL,

    cost_per_application     DECIMAL(18,2) NULL,
    cost_per_hire            DECIMAL(18,2) NULL,

    created_ts               DATETIME2     NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT PK_fact_spend_effectiveness
        PRIMARY KEY (month_start_date, source_id, campaign_id)
);

/* ============================================================
   Step 1: Aggregate marketing spend data (daily -> monthly)
   ============================================================ */

WITH spend_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)   AS month_start_date,
        source_id,
        campaign_id,

        SUM(impressions)                                AS total_impressions,
        SUM(clicks)                                     AS total_clicks,
        SUM(apply_starts)                               AS total_apply_starts,
        SUM(applications_completed)                     AS total_applications,
        SUM(spend_usd)                                  AS total_spend_usd
    FROM dbo.fact_job_board_daily
    GROUP BY
        DATEFROMPARTS(YEAR([date]), MONTH([date]), 1),
        source_id,
        campaign_id
),

/* ============================================================
   Step 2: Aggregate recruiting outcomes monthly
   ============================================================ */

applications_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(apply_date), MONTH(apply_date), 1)   AS month_start_date,
        source_id,
        campaign_id,
        COUNT(*)                                                AS application_count
    FROM dbo.fact_application
    WHERE apply_date IS NOT NULL
    GROUP BY
        DATEFROMPARTS(YEAR(apply_date), MONTH(apply_date), 1),
        source_id,
        campaign_id
),

offers_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(offer_date), MONTH(offer_date), 1)   AS month_start_date,
        fa.source_id,
        fa.campaign_id,
        COUNT(*)                                                AS offer_count
    FROM dbo.fact_offer fo
    JOIN dbo.fact_application fa
        ON fo.application_id = fa.application_id
    WHERE offer_date IS NOT NULL
    GROUP BY
        DATEFROMPARTS(YEAR(offer_date), MONTH(offer_date), 1),
        fa.source_id,
        fa.campaign_id
),

hires_monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)   AS month_start_date,
        fa.source_id,
        fa.campaign_id,
        COUNT(*)                                                AS hire_count
    FROM dbo.fact_hire_hris fh
    JOIN dbo.fact_application fa
        ON fh.application_id = fa.application_id
    WHERE start_date IS NOT NULL
    GROUP BY
        DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1),
        fa.source_id,
        fa.campaign_id
)

/* ============================================================
   Step 3: Combine spend and outcomes
   ============================================================ */

INSERT INTO dbo.fact_spend_effectiveness
(
    month_start_date,
    source_id,
    campaign_id,
    total_impressions,
    total_clicks,
    total_apply_starts,
    total_applications,
    total_spend_usd,
    total_hires,
    total_offers,
    cost_per_application,
    cost_per_hire
)
SELECT
    s.month_start_date,
    ISNULL(s.source_id, 'UNKNOWN')      AS source_id,
    ISNULL(s.campaign_id, 'UNKNOWN')    AS campaign_id,

    s.total_impressions,
    s.total_clicks,
    s.total_apply_starts,
    s.total_applications,
    s.total_spend_usd,

    ISNULL(h.hire_count, 0)             AS total_hires,
    ISNULL(o.offer_count, 0)            AS total_offers,

    CASE
        WHEN s.total_applications > 0
            THEN s.total_spend_usd / s.total_applications
        ELSE NULL
    END AS cost_per_application,

    CASE
        WHEN ISNULL(h.hire_count, 0) > 0
            THEN s.total_spend_usd / h.hire_count
        ELSE NULL
    END                                 AS cost_per_hire

FROM spend_monthly s
LEFT JOIN offers_monthly o
    ON s.month_start_date = o.month_start_date
   AND s.source_id = o.source_id
   AND s.campaign_id = o.campaign_id
LEFT JOIN hires_monthly h
    ON s.month_start_date = h.month_start_date
   AND s.source_id = h.source_id
   AND s.campaign_id = h.campaign_id;


/* ============================================================
   Basic validation
   ============================================================ */

SELECT COUNT(*) AS row_count
FROM dbo.fact_spend_effectiveness;

SELECT TOP (25) *
FROM dbo.fact_spend_effectiveness
ORDER BY month_start_date DESC, total_spend_usd DESC;