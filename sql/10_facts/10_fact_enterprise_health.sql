USE TeamHealthProjectDB;

/* ============================================================
   File: 10_fact_enterprise_health.sql
   Purpose:
     Create a monthly "Enterprise Health" KPI mart for executive reporting.

   Grain:
     One row per month (enterprise-wide).

   KPI Definitions (high level):
     - Open Requisitions: count of requisitions open at month end (proxy snapshot)
     - Avg Time-to-Fill: avg days between open_date and close_date for reqs closed in month
     - Offer Acceptance Rate: accepted / (accepted + declined) for offers decided in month
     - SLA Compliance %: met / (met + not met) for stage events in month where SLA fields are populated
   ============================================================ */

IF OBJECT_ID('dbo.fact_enterprise_health', 'U') IS NOT NULL
    DROP TABLE dbo.fact_enterprise_health;

CREATE TABLE dbo.fact_enterprise_health
(
    month_start_date          DATE        NOT NULL PRIMARY KEY,

    open_reqs_month_end       INT         NOT NULL,
    reqs_closed_in_month      INT         NOT NULL,
    avg_time_to_fill_days     DECIMAL(10,2) NULL,

    offers_decided_in_month   INT         NOT NULL,
    offers_accepted_in_month  INT         NOT NULL,
    offer_accept_rate         DECIMAL(10,4) NULL,

    sla_events_in_month       INT         NOT NULL,
    sla_met_in_month          INT         NOT NULL,
    sla_compliance_rate       DECIMAL(10,4) NULL,

    created_ts                DATETIME2   NOT NULL DEFAULT(SYSDATETIME())
);

/* ============================================================
   Step 1: Build a month calendar from existing data (no dim_date)
   Notes:
     - We derive month_start_date from min/max across key fact dates.
     - This avoids reliance on the non-viable dim_date table.
   ============================================================ */

WITH date_bounds AS
(
    SELECT
    MIN(min_date) AS min_date,
    MAX(max_date) AS max_date
    FROM
    (
        SELECT
            CAST(MIN(open_date)  AS date)   AS min_date,
            CAST(MAX(open_date)  AS date)   AS max_date
        FROM dbo.fact_requisition

        UNION ALL

        SELECT
            CAST(MIN(close_date)            AS date),
            CAST(MAX(close_date)            AS date)
        FROM dbo.fact_requisition

        UNION ALL

        SELECT
            CAST(MIN(offer_date)            AS date),
            CAST(MAX(offer_date)            AS date)
        FROM dbo.fact_offer

        UNION ALL

        SELECT
            CAST(MIN(event_ts)              AS date),
            CAST(MAX(event_ts)              AS date)
        FROM dbo.fact_stage_event
    )x

),

months AS
(
    SELECT
        DATEFROMPARTS(YEAR(min_date), MONTH(min_date), 1) AS month_start_date,
        DATEFROMPARTS(YEAR(min_date), MONTH(min_date), 1) AS start_anchor,
        DATEFROMPARTS(YEAR(max_date), MONTH(max_date), 1) AS end_anchor
    FROM date_bounds

    UNION ALL

    SELECT
        DATEADD(MONTH, 1, month_start_date),
        start_anchor,
        end_anchor
    FROM months
    WHERE month_start_date < end_anchor
),

month_frame AS
(
    SELECT
        month_start_date,
        EOMONTH(month_start_date) AS month_end_date
    FROM months
),

/* ============================================================
   Step 2: Open requisitions at month end (snapshot proxy)
   Definition:
     A requisition is open at month end if:
       open_date <= month_end_date
       AND (close_date IS NULL OR close_date > month_end_date)
   ============================================================ */

open_reqs AS
(
    SELECT
        mf.month_start_date,
        COUNT(*) AS open_reqs_month_end
    FROM month_frame AS mf
    JOIN dbo.fact_requisition AS fr
        ON fr.open_date IS NOT NULL
       AND fr.open_date <= mf.month_end_date
       AND (fr.close_date IS NULL OR fr.close_date > mf.month_end_date)
    GROUP BY mf.month_start_date
),

/* ============================================================
   Step 3: Reqs closed in month + avg time-to-fill
   Definition:
     Only for requisitions with both open_date and close_date populated.
   ============================================================ */

closed_reqs AS
(
    SELECT
        mf.month_start_date,
        COUNT(*)                                                                AS reqs_closed_in_month,
        AVG(CAST(DATEDIFF(DAY, fr.open_date, fr.close_date) AS DECIMAL(10,2)))  AS avg_time_to_fill_days
    FROM month_frame AS mf
    JOIN dbo.fact_requisition AS fr
        ON fr.close_date IS NOT NULL
       AND fr.open_date IS NOT NULL
       AND fr.close_date >= mf.month_start_date
       AND fr.close_date <= mf.month_end_date
    GROUP BY mf.month_start_date
),

/* ============================================================
   Step 4: Offer acceptance rate by month (decisions in month)
   Definition:
     Consider only decided offers (Accepted/Declined) based on offer_status.
     This avoids inflating denominator with Pending offers.
   ============================================================ */

offers AS
(
    SELECT
        mf.month_start_date,
        COUNT(*)                    AS offers_decided_in_month,
        SUM(
            CASE 
                WHEN fo.offer_status = 'Accepted' THEN 1 
                ELSE 0 
            END)                    AS offers_accepted_in_month
    FROM month_frame AS mf
    JOIN dbo.fact_offer AS fo
        ON fo.offer_date IS NOT NULL
       AND fo.offer_date >= mf.month_start_date
       AND fo.offer_date <= mf.month_end_date
       AND fo.offer_status IN ('Accepted', 'Declined')
    GROUP BY mf.month_start_date
),
/* ============================================================
   Step 5: SLA compliance by month (events in month)
   Definition:
     Only include events where SLA fields are populated.
     Use sla_met_flag as source-system KPI after your profiling checks.
   ============================================================ */
sla AS
(
    SELECT
        mf.month_start_date,
        COUNT(*)                    AS sla_events_in_month,
        SUM(
            CASE 
                WHEN fse.sla_met_flag = 1 THEN 1 
                ELSE 0 
            END)                    AS sla_met_in_month
    FROM month_frame AS mf
    JOIN dbo.fact_stage_event AS fse
        ON fse.event_ts IS NOT NULL
       AND fse.event_ts >= mf.month_start_date
       AND fse.event_ts <  DATEADD(DAY, 1, mf.month_end_date)  -- inclusive end-of-month for datetime
       AND fse.sla_days_target IS NOT NULL
       AND fse.days_in_previous_stage IS NOT NULL
       AND fse.sla_met_flag IS NOT NULL
    GROUP BY mf.month_start_date
)
INSERT INTO dbo.fact_enterprise_health
(
    month_start_date,
    open_reqs_month_end,
    reqs_closed_in_month,
    avg_time_to_fill_days,
    offers_decided_in_month,
    offers_accepted_in_month,
    offer_accept_rate,
    sla_events_in_month,
    sla_met_in_month,
    sla_compliance_rate
)
SELECT
    mf.month_start_date,

    ISNULL(orq.open_reqs_month_end, 0)                                          AS open_reqs_month_end,

    ISNULL(cr.reqs_closed_in_month, 0)                                          AS reqs_closed_in_month,
    cr.avg_time_to_fill_days                                                    AS avg_time_to_fill_days,

    ISNULL(ofr.offers_decided_in_month, 0)                                      AS offers_decided_in_month,
    ISNULL(ofr.offers_accepted_in_month, 0)                                     AS offers_accepted_in_month,
    CAST(1.0 * ISNULL(ofr.offers_accepted_in_month, 0)
        / NULLIF(ISNULL(ofr.offers_decided_in_month, 0), 0)AS DECIMAL(10,4))    AS offer_accept_rate,

    ISNULL(s.sla_events_in_month, 0)                                            AS sla_events_in_month,
    ISNULL(s.sla_met_in_month, 0)                                               AS sla_met_in_month,
    CAST(
        1.0 * ISNULL(s.sla_met_in_month, 0)
        / NULLIF(ISNULL(s.sla_events_in_month, 0), 0)
    AS DECIMAL(10,4))                           AS sla_compliance_rate
FROM month_frame AS mf
LEFT JOIN open_reqs AS orq
    ON mf.month_start_date = orq.month_start_date
LEFT JOIN closed_reqs AS cr
    ON mf.month_start_date = cr.month_start_date
LEFT JOIN offers AS ofr
    ON mf.month_start_date = ofr.month_start_date
LEFT JOIN sla AS s
    ON mf.month_start_date = s.month_start_date
ORDER BY mf.month_start_date
OPTION (MAXRECURSION 1000); -- For this query only, allow recursive CTE to recurse up to 1000 levels before stopping

/* ============================================================
   Validation output
   ============================================================ */

SELECT 
TOP (20) *
FROM dbo.fact_enterprise_health
ORDER BY month_start_date DESC;
