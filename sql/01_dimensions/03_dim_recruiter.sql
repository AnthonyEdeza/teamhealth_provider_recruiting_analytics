USE TeamHealthProjectDB;

/* ============================================================
   File: 03_dim_recruiter.sql
   Purpose:
     Build a conformed Recruiter dimension for consistent attribution
     across requisitions, stage events, and outreach activity.

   Why this matters:
     - Recruiter is a core executive axis for capacity, SLA, and load risk
     - Multiple fact tables reference recruiter_id; we need one stable dimension
     - Adds an explicit Unknown member to prevent join-driven row loss
   ============================================================ */

IF OBJECT_ID('dbo.dim_recruiter_conformed', 'U') IS NOT NULL
    DROP TABLE dbo.dim_recruiter_conformed;

CREATE TABLE dbo.dim_recruiter_conformed
(
    recruiter_key                 INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    recruiter_id                  NVARCHAR(50)  NOT NULL,
    recruiter_id_trim             AS NULLIF(LTRIM(RTRIM(recruiter_id)), '') PERSISTED,
    recruiter_name                NVARCHAR(200) NULL,

    recruiter_region_key          INT           NULL,
    recruiter_level               NVARCHAR(50)  NULL,
    team_specialty_focus          NVARCHAR(200) NULL,
    hire_date                     DATE          NULL,

    capacity_target_open_reqs     TINYINT       NULL,

    is_unknown                    BIT           NOT NULL DEFAULT(0),
    source_notes                  NVARCHAR(255) NULL,
    created_ts                    DATETIME2     NOT NULL DEFAULT(SYSDATETIME())
);

/* ============================================================
   Step 1: Insert Recruiters from the authoritative recruiter table
   Notes:
     - dim_recruiter is the source-of-truth for recruiter attributes
     - We trim recruiter_id for safety and exclude blank IDs
   ============================================================ */

INSERT INTO dbo.dim_recruiter_conformed
(
    recruiter_id,
    recruiter_name,
    recruiter_level,
    team_specialty_focus,
    hire_date,
    capacity_target_open_reqs,
    source_notes
)
SELECT
    LTRIM(RTRIM(dr.recruiter_id))                AS recruiter_id,
    NULLIF(LTRIM(RTRIM(dr.recruiter_name)), '')  AS recruiter_name,
    NULLIF(LTRIM(RTRIM(dr.level)), '')           AS recruiter_level,
    NULLIF(LTRIM(RTRIM(dr.team_specialty_focus)), '') AS team_specialty_focus,
    dr.hire_date,
    dr.capacity_target_open_reqs,
    'dim_recruiter' AS source_notes
FROM dbo.dim_recruiter AS dr
WHERE NULLIF(LTRIM(RTRIM(dr.recruiter_id)), '') IS NOT NULL;
GO

/* ============================================================
   Step 2: Map recruiter region -> region_key
   Why:
     - Facts can slice by region using a stable key
     - Avoids relying on raw text fields downstream
   ============================================================ */

UPDATE rc
SET recruiter_region_key = r.region_key
FROM dbo.dim_recruiter_conformed AS rc
JOIN dbo.dim_recruiter AS dr
    ON LTRIM(RTRIM(dr.recruiter_id)) = rc.recruiter_id
LEFT JOIN dbo.dim_region AS r
    ON UPPER(NULLIF(LTRIM(RTRIM(dr.region)), '')) = r.region_name_upper;

/* ============================================================
   Step 3: Add Unknown recruiter member
   Why:
     - Fact tables can contain recruiter_id that is NULL or unmapped
     - This prevents losing rows in joins and keeps totals honest
   ============================================================ */

IF NOT EXISTS (SELECT 1 FROM dbo.dim_recruiter_conformed WHERE is_unknown = 1)
BEGIN
    INSERT INTO dbo.dim_recruiter_conformed
    (
        recruiter_id,
        recruiter_name,
        recruiter_level,
        team_specialty_focus,
        hire_date,
        capacity_target_open_reqs,
        recruiter_region_key,
        is_unknown,
        source_notes
    )
    VALUES
    (
        'Unknown',
        'Unknown',
        NULL,
        NULL,
        NULL,
        NULL,
        (SELECT region_key FROM dbo.dim_region WHERE is_unknown = 1),
        1,
        'System row for NULL/unmapped recruiters'
    );
END;

/* ============================================================
   Step 4: Conformance checks (does every fact recruiter_id exist in dim?)
   Output should ideally be 0 rows for each check
   ============================================================ */

-- 4A) fact_requisition.recruiter_id not in recruiter dimension
SELECT
    'fact_requisition.recruiter_id' AS source_field,
    LTRIM(RTRIM(fr.recruiter_id))   AS recruiter_id,
    COUNT(*)                       AS row_count
FROM dbo.fact_requisition AS fr
LEFT JOIN dbo.dim_recruiter_conformed AS rc
    ON LTRIM(RTRIM(fr.recruiter_id)) = rc.recruiter_id
WHERE NULLIF(LTRIM(RTRIM(fr.recruiter_id)), '') IS NOT NULL
  AND rc.recruiter_id IS NULL
GROUP BY LTRIM(RTRIM(fr.recruiter_id))
ORDER BY row_count DESC;

-- 4B) fact_stage_event.recruiter_id not in recruiter dimension
SELECT
    'fact_stage_event.recruiter_id' AS source_field,
    LTRIM(RTRIM(fse.recruiter_id))  AS recruiter_id,
    COUNT(*)                       AS row_count
FROM dbo.fact_stage_event AS fse
LEFT JOIN dbo.dim_recruiter_conformed AS rc
    ON LTRIM(RTRIM(fse.recruiter_id)) = rc.recruiter_id
WHERE NULLIF(LTRIM(RTRIM(fse.recruiter_id)), '') IS NOT NULL
  AND rc.recruiter_id IS NULL
GROUP BY LTRIM(RTRIM(fse.recruiter_id))
ORDER BY row_count DESC;

-- 4C) fact_outreach_event.recruiter_id not in recruiter dimension
SELECT
    'fact_outreach_event.recruiter_id' AS source_field,
    LTRIM(RTRIM(foe.recruiter_id))     AS recruiter_id,
    COUNT(*)                           AS row_count
FROM dbo.fact_outreach_event AS foe
LEFT JOIN dbo.dim_recruiter_conformed AS rc
    ON LTRIM(RTRIM(foe.recruiter_id)) = rc.recruiter_id
WHERE NULLIF(LTRIM(RTRIM(foe.recruiter_id)), '') IS NOT NULL
  AND rc.recruiter_id IS NULL
GROUP BY LTRIM(RTRIM(foe.recruiter_id))
ORDER BY row_count DESC;

/* ============================================================
   Step 5: Quick validation outputs
   ============================================================ */

SELECT
    COUNT(*) AS recruiter_count,
    SUM(CASE WHEN is_unknown = 1 THEN 1 ELSE 0 END) AS unknown_rows,
    SUM(CASE WHEN recruiter_region_key IS NULL AND is_unknown = 0 THEN 1 ELSE 0 END) AS recruiters_missing_region_key
FROM dbo.dim_recruiter_conformed;

SELECT TOP (50)
    recruiter_key,
    recruiter_id,
    recruiter_name,
    recruiter_level,
    team_specialty_focus,
    recruiter_region_key,
    capacity_target_open_reqs,
    hire_date,
    is_unknown,
    source_notes,
    created_ts
FROM dbo.dim_recruiter_conformed
ORDER BY
    is_unknown ASC,
    recruiter_name ASC,
    recruiter_id ASC;
