USE TeamHealthProjectDB;

/* ============================================================
   File: 02_dim_region.sql
   Purpose:
     Build a conformed Region dimension so Region is consistent
     across Facilities, Recruiters, Candidates, and Campaigns.

   Why this matters (Power BI + executive reporting):
     - Prevents fragmented slicers (e.g., "West", "WEST ", "West Region")
     - Ensures all fact tables roll up to the same Region axis
     - Provides an "Unknown" member so NULLs don't break visuals
   ============================================================ */

IF OBJECT_ID('dbo.dim_region', 'U') IS NOT NULL
    DROP TABLE dbo.dim_region;

CREATE TABLE dbo.dim_region
(
    region_key         INT IDENTITY(1,1)  NOT NULL PRIMARY KEY,
    region_name        NVARCHAR(100)      NOT NULL,
    region_name_upper  AS UPPER(region_name) PERSISTED,
    is_unknown         BIT                NOT NULL DEFAULT(0),
    source_notes       NVARCHAR(255)      NULL,
    created_ts         DATETIME2          NOT NULL DEFAULT(SYSDATETIME())
);

/* ============================================================
   Step 1: Collect region values from all relevant sources
   Notes:
     - Trim whitespace
     - Convert empty strings to NULL
   ============================================================ */

WITH region_raw AS
(
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(region)), '') AS region_name,
        'dim_facility.region'            AS source_notes
    FROM dbo.dim_facility
    WHERE NULLIF(LTRIM(RTRIM(region)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(region)), ''),
        'dim_recruiter.region'
    FROM dbo.dim_recruiter
    WHERE NULLIF(LTRIM(RTRIM(region)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(region)), ''),
        'fact_candidate.region'
    FROM dbo.fact_candidate
    WHERE NULLIF(LTRIM(RTRIM(region)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(region)), ''),
        'dim_campaign.region'
    FROM dbo.dim_campaign
    WHERE NULLIF(LTRIM(RTRIM(region)), '') IS NOT NULL

    UNION

    -- dim_date is included only because it contains region columns, even if the table is non-viable as a date dimension.
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(region)), ''),
        'dim_date.region (table non-viable; region only)'
    FROM dbo.dim_date
    WHERE NULLIF(LTRIM(RTRIM(region)), '') IS NOT NULL
),

region_dedup AS
(
    -- If the same region appears  from multiple source, keep one row.
    SELECT
        region_name,
        MIN(source_notes) AS source_notes
    FROM region_raw
    GROUP BY region_name
)

INSERT INTO dbo.dim_region (region_name, source_notes)

SELECT
    region_name,
    source_notes
FROM region_dedup
ORDER BY region_name;

/* ============================================================
   Step 2: Add an explicit Unknown member
   Why:
     - Power BI slicers and joins behave better when NULLs map to a known bucket
     - Keeps totals stable and prevents silent row loss during joins
   ============================================================ */

IF NOT EXISTS (SELECT 1 FROM dbo.dim_region WHERE is_unknown = 1)
BEGIN
    INSERT INTO dbo.dim_region (region_name, is_unknown, source_notes)
    VALUES ('Unknown', 1, 'System row for NULL/unmapped regions');
END;

/* ============================================================
   Step 3: Validation outputs (quick sanity checks)
   ============================================================ */

-- 3A) How many regions do we have?
SELECT
    COUNT(*) AS region_count,
    SUM(CASE WHEN is_unknown = 1 THEN 1 ELSE 0 END) AS unknown_rows
FROM dbo.dim_region;

-- 3B) List regions (good for verifying no weird whitespace/duplicates)
SELECT
    region_key,
    region_name,
    is_unknown,
    source_notes,
    created_ts
FROM dbo.dim_region
ORDER BY
    is_unknown ASC,
    region_name ASC;

/* ============================================================
   Step 4: Conformance checks
   Why: 
    - Confirm each source table only uses values in dim_region.
   ============================================================ */

-- dim_facility.region not in dim_region
SELECT
    'dim_facility.region' AS source_field,
    NULLIF(LTRIM(RTRIM(df.region)), '') AS region_value,
    COUNT(*) AS row_count
FROM dbo.dim_facility AS df
LEFT JOIN dbo.dim_region AS r
    ON UPPER(NULLIF(LTRIM(RTRIM(df.region)), '')) = r.region_name_upper
WHERE NULLIF(LTRIM(RTRIM(df.region)), '') IS NOT NULL
  AND r.region_key IS NULL
GROUP BY NULLIF(LTRIM(RTRIM(df.region)), '')
ORDER BY row_count DESC;

-- dim_recruiter.region not in dim_region
SELECT
    'dim_recruiter.region' AS source_field,
    NULLIF(LTRIM(RTRIM(dr.region)), '') AS region_value,
    COUNT(*) AS row_count
FROM dbo.dim_recruiter AS dr
LEFT JOIN dbo.dim_region AS r
    ON UPPER(NULLIF(LTRIM(RTRIM(dr.region)), '')) = r.region_name_upper
WHERE NULLIF(LTRIM(RTRIM(dr.region)), '') IS NOT NULL
  AND r.region_key IS NULL
GROUP BY NULLIF(LTRIM(RTRIM(dr.region)), '')
ORDER BY row_count DESC;

-- fact_candidate.region not in dim_region
SELECT
    'fact_candidate.region' AS source_field,
    NULLIF(LTRIM(RTRIM(fc.region)), '') AS region_value,
    COUNT(*) AS row_count
FROM dbo.fact_candidate AS fc
LEFT JOIN dbo.dim_region AS r
    ON UPPER(NULLIF(LTRIM(RTRIM(fc.region)), '')) = r.region_name_upper
WHERE NULLIF(LTRIM(RTRIM(fc.region)), '') IS NOT NULL
  AND r.region_key IS NULL
GROUP BY NULLIF(LTRIM(RTRIM(fc.region)), '')
ORDER BY row_count DESC;
