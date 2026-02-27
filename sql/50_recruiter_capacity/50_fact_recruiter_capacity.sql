USE TeamHealthProjectDB;

/* ============================================================
   File: 50_fact_recruiter_capacity.sql

   Purpose:
     Measure recruiter workload and capacity utilization monthly.

   Business Questions Supported:
     - How many open requisitions does each recruiter manage?
     - Who is above or below their capacity target?
     - What percentage of recruiters exceed target load?
     - How does workload trend month-over-month?

   Grain:
     One row per month_start_date × recruiter_id

   Notes:
     - A requisition is considered open if:
         open_date <= month_end
         AND (close_date IS NULL OR close_date > month_end)
     - Capacity target is sourced from dim_recruiter.capacity_target_open_reqs
   ============================================================ */

IF OBJECT_ID('dbo.fact_recruiter_capacity', 'U') IS NOT NULL
    DROP TABLE dbo.fact_recruiter_capacity;

CREATE TABLE dbo.fact_recruiter_capacity
(
    month_start_date              DATE          NOT NULL,
    recruiter_id                  NVARCHAR(50)  NOT NULL,

    recruiter_level               NVARCHAR(100) NULL,
    region                        NVARCHAR(100) NULL,
    team_specialty_focus          NVARCHAR(100) NULL,

    open_reqs                     INT           NOT NULL,
    capacity_target_open_reqs     INT           NULL,

    capacity_gap                  INT           NULL,   -- open_reqs - capacity_target
    over_capacity_flag            BIT           NOT NULL,

    created_ts                    DATETIME2     NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT PK_fact_recruiter_capacity
        PRIMARY KEY (month_start_date, recruiter_id)
);

/* ============================================================
   Step 1: Build month frame from requisition activity
   ============================================================ */

WITH date_bounds AS
(
    SELECT
        DATEFROMPARTS(YEAR(MIN(open_date)), MONTH(MIN(open_date)), 1)                                           AS min_month,
        DATEFROMPARTS(YEAR(MAX(ISNULL(close_date, GETDATE()))), MONTH(MAX(ISNULL(close_date, GETDATE()))), 1)   AS max_month
    FROM dbo.fact_requisition
),
months AS
(
    SELECT min_month AS month_start_date
    FROM date_bounds

    UNION ALL

    SELECT DATEADD(MONTH, 1, month_start_date)
    FROM months
    CROSS JOIN date_bounds
    WHERE month_start_date < max_month
),

/* ============================================================
   Step 2: Calculate open requisitions per recruiter per month
   ============================================================ */

open_reqs_monthly AS
(
    SELECT
        m.month_start_date,
        fr.recruiter_id,
        COUNT(*) AS open_reqs
    FROM months m
    JOIN dbo.fact_requisition fr
        ON fr.open_date <= EOMONTH(m.month_start_date)
       AND (fr.close_date IS NULL OR fr.close_date > EOMONTH(m.month_start_date))
    WHERE fr.recruiter_id IS NOT NULL
    GROUP BY
        m.month_start_date,
        fr.recruiter_id
)

INSERT INTO dbo.fact_recruiter_capacity
(
    month_start_date,
    recruiter_id,
    recruiter_level,
    region,
    team_specialty_focus,
    open_reqs,
    capacity_target_open_reqs,
    capacity_gap,
    over_capacity_flag
)
SELECT
    o.month_start_date,
    o.recruiter_id,

    dr.level,
    dr.region,
    dr.team_specialty_focus,

    o.open_reqs,
    dr.capacity_target_open_reqs,

    o.open_reqs - ISNULL(dr.capacity_target_open_reqs, 0) AS capacity_gap,

    CASE
        WHEN dr.capacity_target_open_reqs IS NOT NULL
             AND o.open_reqs > dr.capacity_target_open_reqs
        THEN 1
        ELSE 0
    END AS over_capacity_flag

FROM open_reqs_monthly o
LEFT JOIN dbo.dim_recruiter dr
    ON o.recruiter_id = dr.recruiter_id
OPTION (MAXRECURSION 0);

/* ============================================================
   Validation
   ============================================================ */

SELECT 
    COUNT(*)        AS row_count
FROM dbo.fact_recruiter_capacity;

-- Confirm grain uniqueness (should return 0 rows) any rows here would indicate duplicate grain buckets.
SELECT
    month_start_date,
    recruiter_id,
    COUNT(*)        AS rows_in_bucket
FROM dbo.fact_recruiter_capacity
GROUP BY 
    month_start_date,
    recruiter_id
HAVING COUNT(*) > 1;



SELECT 
    TOP (25) *
FROM dbo.fact_recruiter_capacity
ORDER BY 
    month_start_date DESC,
    open_reqs DESC;