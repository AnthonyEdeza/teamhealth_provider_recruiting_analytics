USE TeamHealthProjectDB;

/* ============================================================
   File: 01_dim_specialty.sql
   Purpose:
     Build a conformed Specialty dimension to standardize specialty
     labels across roles, candidates, campaigns, and recruiter focus.
   Why it matters:
     Prevents fragmented slicers and inconsistent KPI grouping in Power BI.
   ============================================================ */

/* Notes:
   - Specialty values are already standardized in the source system.
   - Campaign taxonomy (dim_campaign.target_specialty) is treated as authoritative.
   - No synonym normalization required at this stage.
*/

IF OBJECT_ID('dbo.dim_specialty', 'U') IS NOT NULL
    DROP TABLE dbo.dim_specialty;

CREATE TABLE dbo.dim_specialty
(
    specialty_key       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    specialty_name      NVARCHAR(255)      NOT NULL,
    specialty_name_upper AS UPPER(specialty_name) PERSISTED,  -- helps matching in downstream joins
    is_unknown          BIT                NOT NULL DEFAULT(0),
    source_notes        NVARCHAR(255)      NULL,
    created_ts          DATETIME2          NOT NULL DEFAULT(SYSDATETIME())
);

/* ============================================================
   Step 1: Collect raw specialty values from all relevant columns.
   Notes:
     - trim whitespace and remove empty-string values.
   ============================================================ */

WITH specialty_raw AS
(
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(specialty)), '') AS specialty_name,
        'dim_role.specialty' AS source_notes
    FROM dbo.dim_role
    WHERE NULLIF(LTRIM(RTRIM(specialty)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(primary_specialty)), ''),
        'fact_candidate.primary_specialty'
    FROM dbo.fact_candidate
    WHERE NULLIF(LTRIM(RTRIM(primary_specialty)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(target_specialty)), ''),
        'dim_campaign.target_specialty'
    FROM dbo.dim_campaign
    WHERE NULLIF(LTRIM(RTRIM(target_specialty)), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(team_specialty_focus)), ''),
        'dim_recruiter.team_specialty_focus'
    FROM dbo.dim_recruiter
    WHERE NULLIF(LTRIM(RTRIM(team_specialty_focus)), '') IS NOT NULL
),

specialty_dedup AS
(
    -- If the same specialty appears from multiple sources, keep one row.
    SELECT
        specialty_name,
        MIN(source_notes) AS source_notes
    FROM specialty_raw
    GROUP BY specialty_name
)

INSERT INTO dbo.dim_specialty (specialty_name, source_notes)

SELECT
    specialty_name,
    source_notes
FROM specialty_dedup
ORDER BY specialty_name;

/* ============================================================
   Step 2: Add an explicit Unknown row 
   Why:
    - For unmatched/missing specialty
   ============================================================ */

IF NOT EXISTS (SELECT 1 FROM dbo.dim_specialty WHERE is_unknown = 1)
BEGIN
    INSERT INTO dbo.dim_specialty (specialty_name, is_unknown, source_notes)
    VALUES ('Unknown', 1, 'System row for NULL/unmapped specialties');
END;
GO

/* ============================================================
   Step 3: Quick validation outputs
   ============================================================ */

SELECT
    COUNT(*) AS specialty_count,
    SUM(CASE WHEN is_unknown = 1 THEN 1 ELSE 0 END) AS unknown_rows
FROM dbo.dim_specialty;

SELECT TOP (50) *
FROM dbo.dim_specialty
ORDER BY 
    specialty_key ASC, 
    specialty_name ASC;
