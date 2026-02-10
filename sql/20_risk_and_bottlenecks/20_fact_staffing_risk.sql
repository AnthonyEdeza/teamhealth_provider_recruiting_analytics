USE TeamHealthProjectDB;

/* ============================================================
   File: 20_fact_staffing_risk.sql

   Purpose:
     Create a monthly staffing risk table used to support:
       - Specialty × Region heatmaps
       - Aging open requisition analysis
       - Identification of backlog and bottleneck risk
       - Rural vs non-rural staffing comparisons

   This table is designed to answer the question:
     "Where are we most exposed to staffing risk, and why?"

   Grain:
     One row per month_start_date × region_key × specialty_key

   Notes / Assumptions:
     - There is no daily snapshot table in this dataset.
       Open requisitions are reconstructed using open_date and close_date.
     - A requisition is considered "open at month end" if:
         open_date <= month_end_date
         AND (close_date IS NULL OR close_date > month_end_date)
     - The definition of "at risk" is based on requisition age and is
       parameterized so it can be adjusted without rewriting the query.
   ============================================================ */

DECLARE @risk_age_threshold_days INT = 60;  -- Business-defined threshold parameter for aging risk

IF OBJECT_ID('dbo.fact_staffing_risk', 'U') IS NOT NULL
    DROP TABLE dbo.fact_staffing_risk;

CREATE TABLE dbo.fact_staffing_risk
(
    month_start_date             DATE          NOT NULL,
    region_key                   INT           NOT NULL,
    specialty_key                INT           NOT NULL,

    open_reqs_month_end          INT           NOT NULL,
    open_positions_month_end     INT           NOT NULL,

    avg_age_days_open_reqs       DECIMAL(10,2) NULL,
    open_reqs_over_threshold     INT           NOT NULL,
    hard_to_fill_open_reqs       INT           NOT NULL,

    rural_open_reqs_month_end    INT           NOT NULL,
    nonrural_open_reqs_month_end INT           NOT NULL,
    rural_nonrural_age_delta     DECIMAL(10,2) NULL,

    created_ts                   DATETIME2     NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT PK_fact_staffing_risk
        PRIMARY KEY (month_start_date, region_key, specialty_key) -- One row per month × region × specialty grain
);

/* ============================================================
   Step 1: Generate a month-level frame

   Since there is no usable date dimension in this dataset,
   the month range is derived directly from requisition activity.
   ============================================================ */

WITH date_bounds AS
(
    SELECT
        MIN(CAST(open_date AS DATE)) AS min_date,
        MAX(CAST(COALESCE(close_date, open_date) AS DATE)) AS max_date -- For each requisition, treat its ‘ending’ date as close_date if it exists, otherwise open_date
    FROM dbo.fact_requisition
    WHERE open_date IS NOT NULL
),

months AS
(
    SELECT
        DATEFROMPARTS(YEAR(min_date), MONTH(min_date), 1) AS month_start_date, -- If min_date is 2024-01-12 then it'll be converted to 2024-01-01
        DATEFROMPARTS(YEAR(min_date), MONTH(min_date), 1) AS start_anchor,     -- same as 2024-01-01
        DATEFROMPARTS(YEAR(max_date), MONTH(max_date), 1) AS end_anchor        -- we'll say max_date is 2024-05-01
    FROM date_bounds

    UNION ALL

    SELECT
        DATEADD(MONTH, 1, month_start_date), -- recursion occurs, uses month 1 as start point
        start_anchor,
        end_anchor
    FROM months
    WHERE month_start_date < end_anchor -- and will keep adding 1 month until it ends at end_anchor month, in this case 5
),

month_frame AS                 
(
    SELECT
        month_start_date,
        EOMONTH(month_start_date) AS month_end_date  -- converts start of month to end of month eg. 2024-01-01 -> 2024-01-31
    FROM months
),

/* ============================================================
   Step 2: Resolve "Unknown" keys for conformed dimensions

   This ensures all records can be grouped even when source
   attributes are missing or unmapped.
   ============================================================ */

unknown_keys AS   -- pulls "Unknown" dimension surrogate keys to use when a record is missing/mismatched on Region/Specialty

(
    SELECT
        (SELECT TOP 1 region_key
         FROM dbo.dim_region
         WHERE is_unknown = 1) AS unknown_region_key,

        (SELECT TOP 1 specialty_key
         FROM dbo.dim_specialty
         WHERE is_unknown = 1) AS unknown_specialty_key
),

/* ============================================================
   Step 3: Identify requisitions open at month end and enrich
           them with attributes needed for risk analysis
   ============================================================ */

open_reqs AS
(
    SELECT
        mf.month_start_date,
        mf.month_end_date,

        fr.req_id,
        ISNULL(fr.openings_count, 1)                    AS openings_count,
        fr.open_date,

        DATEDIFF(DAY, fr.open_date, mf.month_end_date)  AS age_days_open,

        ISNULL(df.is_rural, 0)                          AS is_rural,
        df.region                                       AS facility_region,

        ISNULL(dr.is_hard_to_fill, 0)                   AS is_hard_to_fill,
        dr.specialty                                    AS role_specialty

    FROM month_frame mf
    INNER JOIN dbo.fact_requisition fr
        ON fr.open_date IS NOT NULL
       AND fr.open_date <= mf.month_end_date
       AND (fr.close_date IS NULL OR fr.close_date > mf.month_end_date)

    LEFT JOIN dbo.dim_facility df
        ON fr.facility_id = df.facility_id

    LEFT JOIN dbo.dim_role dr
        ON fr.role_id = dr.role_id
),

/* ============================================================
   Step 4: Map region and specialty to conformed dimension keys

   - Region is sourced from the facility associated with the requisition
   - Specialty is sourced from the role tied to the requisition
   - Missing values are grouped into explicit "Unknown" buckets
   ============================================================ */

open_reqs_keyed AS
(
    SELECT
        o.month_start_date,
        o.req_id,
        o.openings_count,
        o.age_days_open,
        o.is_rural,
        o.is_hard_to_fill,

        COALESCE(r.region_key, uk.unknown_region_key)       AS region_key,
        COALESCE(s.specialty_key, uk.unknown_specialty_key) AS specialty_key

-- Attach single-row Unknown dimension keys to each row for COALESCE fallbacks (CROSS JOIN is safe because unknown_keys returns 1 row)

    FROM open_reqs o
    CROSS JOIN unknown_keys uk        
    LEFT JOIN dbo.dim_region r
        ON UPPER(NULLIF(LTRIM(RTRIM(o.facility_region)), '')) = r.region_name_upper
    LEFT JOIN dbo.dim_specialty s
        ON UPPER(NULLIF(LTRIM(RTRIM(o.role_specialty)), '')) = s.specialty_name_upper
),

/* ============================================================
   Step 5: Aggregate to reporting grain

   Metrics produced here are intentionally simple and transparent,
   supporting direct use in Power BI visuals.
   ============================================================ */

agg AS
(
    SELECT
        month_start_date,
        region_key,
        specialty_key,

        COUNT(*)                                    AS open_reqs_month_end,
        SUM(openings_count)                         AS open_positions_month_end,

        AVG(CAST(age_days_open AS DECIMAL(10,2)))   AS avg_age_days_open_reqs,

        SUM(CASE
                WHEN age_days_open > @risk_age_threshold_days THEN 1
                ELSE 0
            END) AS open_reqs_over_threshold,

        SUM(CASE
                WHEN is_hard_to_fill = 1 THEN 1
                ELSE 0
            END) AS hard_to_fill_open_reqs,

        SUM(CASE WHEN is_rural = 1 THEN 1 ELSE 0 END) AS rural_open_reqs_month_end,
        SUM(CASE WHEN is_rural = 0 THEN 1 ELSE 0 END) AS nonrural_open_reqs_month_end,

        AVG(CASE WHEN is_rural = 1 THEN CAST(age_days_open AS DECIMAL(10,2)) END) AS avg_age_rural,
        AVG(CASE WHEN is_rural = 0 THEN CAST(age_days_open AS DECIMAL(10,2)) END) AS avg_age_nonrural
    FROM open_reqs_keyed
    GROUP BY
        month_start_date,
        region_key,
        specialty_key
)

/* ============================================================
   Final Step: Insert aggregated monthly risk metrics

   All CTEs above culminate in the `agg` result set.
   The INSERT statement below persists those results
   into the fact_staffing_risk table.
   ============================================================ */


INSERT INTO dbo.fact_staffing_risk
(
    month_start_date,
    region_key,
    specialty_key,
    open_reqs_month_end,
    open_positions_month_end,
    avg_age_days_open_reqs,
    open_reqs_over_threshold,
    hard_to_fill_open_reqs,
    rural_open_reqs_month_end,
    nonrural_open_reqs_month_end,
    rural_nonrural_age_delta
)

SELECT
    month_start_date,
    region_key,
    specialty_key,
    open_reqs_month_end,
    open_positions_month_end,
    avg_age_days_open_reqs,
    open_reqs_over_threshold,
    hard_to_fill_open_reqs,
    rural_open_reqs_month_end,
    nonrural_open_reqs_month_end,
    CAST(avg_age_rural - avg_age_nonrural AS DECIMAL(10,2)) AS rural_nonrural_age_delta
FROM agg
ORDER BY
    month_start_date,
    region_key,
    specialty_key;

/* ============================================================
   Post-load validation (sanity checks)
   ============================================================ */

-- Basic validation output

SELECT COUNT(*) AS row_count
FROM dbo.fact_staffing_risk;

SELECT TOP (25) *
FROM dbo.fact_staffing_risk
ORDER BY 
    month_start_date DESC, 
    open_reqs_month_end DESC;

-- Validate grain uniqueness (expected: 0 rows)

SELECT
    month_start_date, 
    region_key,
    specialty_key,
    COUNT(*) AS rows_in_bucket
FROM dbo.fact_staffing_risk
GROUP BY 
    month_start_date,
    region_key,
    specialty_key
HAVING COUNT(*) > 1;

-- Time coverage validation

SELECT
    COUNT(DISTINCT month_start_date)  AS months_loaded,
    MIN(month_start_date)             AS first_month,
    MAX(month_start_date)             AS last_month
FROM dbo.fact_staffing_risk;

-- Key completeness (expected: 0 NULL keys)

SELECT
    SUM(CASE WHEN region_key IS NULL THEN 1 ELSE 0 END)     AS null_region_key_rows,
    SUM(CASE WHEN specialty_key IS NULL THEN 1 ELSE 0 END)  AS null_specialty_key_rows
FROM dbo.fact_staffing_risk;

-- Volume reasonableness check (detect unintended row multiplication)

SELECT TOP (10)
    month_start_date, 
    region_key, 
    specialty_key,
    open_reqs_month_end, 
    open_positions_month_end
FROM dbo.fact_staffing_risk
ORDER BY 
    open_reqs_month_end DESC;
