USE teamHealthProjectDB

/* =========================================================
   File: 00_profiling.sql
   Purpose: Baseline data profiling and integrity validation
   Database: teamHealthProjectDB
   Schema: dbo
   ========================================================= */


/* =========================================================
   Section 1: Row counts by table
   Purpose: Confirm load completeness and get a quick sense of scale.
   Status: Completed
   Notes:
    - dim_date appears non-viable in this dataset 
        (it duplicates dim_facility columns and has no date key).
   ========================================================= */

SELECT
    'dbo.dim_campaign' AS table_name,
    COUNT(*)           AS row_count
FROM dbo.dim_campaign

UNION ALL

SELECT
    'dbo.dim_date' AS table_name,
    COUNT(*)       AS row_count
FROM dbo.dim_date

UNION ALL

SELECT
    'dbo.dim_facility' AS table_name,
    COUNT(*)           AS row_count
FROM dbo.dim_facility

UNION ALL

SELECT
    'dbo.dim_recruiter' AS table_name,
    COUNT(*)            AS row_count
FROM dbo.dim_recruiter

UNION ALL

SELECT
    'dbo.dim_role' AS table_name,
    COUNT(*)       AS row_count
FROM dbo.dim_role

UNION ALL

SELECT
    'dbo.dim_source' AS table_name,
    COUNT(*)         AS row_count
FROM dbo.dim_source

UNION ALL

SELECT
    'dbo.fact_application' AS table_name,
    COUNT(*)               AS row_count
FROM dbo.fact_application

UNION ALL

SELECT
    'dbo.fact_candidate' AS table_name,
    COUNT(*)             AS row_count
FROM dbo.fact_candidate

UNION ALL

SELECT
    'dbo.fact_hire_hris' AS table_name,
    COUNT(*)             AS row_count
FROM dbo.fact_hire_hris

UNION ALL

SELECT
    'dbo.fact_job_board_daily' AS table_name,
    COUNT(*)                   AS row_count
FROM dbo.fact_job_board_daily

UNION ALL

SELECT
    'dbo.fact_offer' AS table_name,
    COUNT(*)         AS row_count
FROM dbo.fact_offer

UNION ALL

SELECT
    'dbo.fact_outreach_event' AS table_name,
    COUNT(*)                  AS row_count
FROM dbo.fact_outreach_event

UNION ALL

SELECT
    'dbo.fact_requisition' AS table_name,
    COUNT(*)               AS row_count
FROM dbo.fact_requisition

UNION ALL

SELECT
    'dbo.fact_stage_event' AS table_name,
    COUNT(*)               AS row_count
FROM dbo.fact_stage_event
ORDER BY row_count DESC;


/* =========================================================
   Section 2: Date coverage per table (timeline validity)
   Purpose: Validate date ranges for key lifecycle columns that drive KPIs.
   Notes:
    - dim_date appears non-viable in this dataset (duplicate of dim_facility per investigation).
   ========================================================= */


SELECT
    'dbo.fact_requisition'  AS table_name,
    MIN(open_date)          AS date_1_min,
    MAX(open_date)          AS date_1_max,
    MIN(close_date)         AS date_2_min,
    MAX(close_date)         AS date_2_max,
    MIN(target_start_date)  AS date_3_min,
    MAX(target_start_date)  AS date_3_max
FROM dbo.fact_requisition

UNION ALL

SELECT
    'dbo.fact_offer'            AS table_name,
    MIN(offer_date)             AS date_1_min,
    MAX(offer_date)             AS date_1_max,
    MIN(proposed_start_date)    AS date_2_min,
    MAX(proposed_start_date)    AS date_2_max,
    NULL                        AS date_3_min,
    NULL                        AS date_3_max
FROM dbo.fact_offer

UNION ALL

SELECT
    'dbo.fact_hire_hris'    AS table_name,
    MIN(start_date)         AS date_1_min,
    MAX(start_date)         AS date_1_max,
    MIN(termination_date)   AS date_2_min,
    MAX(termination_date)   AS date_2_max,
    NULL                    AS date_3_min,
    NULL                    AS date_3_max
FROM dbo.fact_hire_hris

UNION ALL

SELECT
    'dbo.fact_stage_event'  AS table_name,
    MIN(event_ts)           AS date_1_min,
    MAX(event_ts)           AS date_1_max,
    NULL                    AS date_2_min,
    NULL                    AS date_2_max,
    NULL                    AS date_3_min,
    NULL                    AS date_3_max
FROM dbo.fact_stage_event

UNION ALL

SELECT
    'dbo.fact_job_board_daily'  AS table_name,
    MIN([date])                 AS date_1_min,
    MAX([date])                 AS date_1_max,
    NULL                        AS date_2_min,
    NULL                        AS date_2_max,
    NULL                        AS date_3_min,
    NULL                        AS date_3_max
FROM dbo.fact_job_board_daily

UNION ALL

SELECT
    'dbo.fact_application'  AS table_name,
    MIN(apply_date)         AS date_1_min,
    MAX(apply_date)         AS date_1_max,
    NULL                    AS date_2_min,
    NULL                    AS date_2_max,
    NULL                    AS date_3_min,
    NULL                    AS date_3_max
FROM dbo.fact_application

UNION ALL

SELECT
    'dbo.fact_candidate'    AS table_name,
    MIN(lead_create_date)   AS date_1_min,
    MAX(lead_create_date)   AS date_1_max,
    NULL                    AS date_2_min,
    NULL                    AS date_2_max,
    NULL                    AS date_3_min,
    NULL                    AS date_3_max
FROM dbo.fact_candidate

UNION ALL

SELECT
    'dbo.fact_outreach_event'   AS table_name,
    MIN(outreach_ts)            AS date_1_min,
    MAX(outreach_ts)            AS date_1_max,
    NULL                        AS date_2_min,
    NULL                        AS date_2_max,
    NULL                        AS date_3_min,
    NULL                        AS date_3_max
FROM dbo.fact_outreach_event

UNION ALL

SELECT
    'dbo.dim_campaign'  AS table_name,
    MIN(start_date)     AS date_1_min,
    MAX(start_date)     AS date_1_max,
    MIN(end_date)       AS date_2_min,
    MAX(end_date)       AS date_2_max,
    NULL                AS date_3_min,
    NULL                AS date_3_max
FROM dbo.dim_campaign

UNION ALL

SELECT
    'dbo.dim_recruiter'     AS table_name,
    MIN(hire_date)          AS date_1_min,
    MAX(hire_date)          AS date_1_max,
    NULL                    AS date_2_min,
    NULL                    AS date_2_max,
    NULL                    AS date_3_min,
    NULL                    AS date_3_max
FROM dbo.dim_recruiter;



/* ============================================================
   Section 3: PRIMARY KEY QUALITY CHECKS (NULLs + BLANKS + DUPLICATES) - UNIONED
   Notes:
   - duplicate_pk is calculated as: COUNT(pk) - COUNT(DISTINCT pk)
     This excludes NULLs from duplicate calculation.
   - blank_pk counts empty-string or whitespace-only PK values for nvarchar keys.
   ============================================================ */

SELECT *
FROM (
    SELECT
        'dbo.dim_campaign' AS table_name,
        'campaign_id' AS pk_column,
        COUNT(*) AS total_rows,
        SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) AS null_pk,
        SUM(CASE WHEN LTRIM(RTRIM(campaign_id)) = '' THEN 1 ELSE 0 END) AS blank_pk,
        COUNT(campaign_id) - COUNT(DISTINCT campaign_id) AS duplicate_pk
    FROM dbo.dim_campaign

    UNION ALL

    SELECT
        'dbo.dim_facility', 'facility_id',
        COUNT(*),
        SUM(CASE WHEN facility_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(facility_id)) = '' THEN 1 ELSE 0 END),
        COUNT(facility_id) - COUNT(DISTINCT facility_id)
    FROM dbo.dim_facility

    UNION ALL

    --dim_date and dim_facility are exactly the same

    SELECT 'dbo.dim_date','facility_id', 
        COUNT(*),
        SUM(CASE WHEN facility_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(facility_id)) = '' THEN 1 ELSE 0 END),
        COUNT(facility_id) - COUNT(DISTINCT facility_id)
    FROM dbo.dim_date

    UNION ALL

    SELECT
        'dbo.dim_recruiter', 'recruiter_id',
        COUNT(*),
        SUM(CASE WHEN recruiter_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(recruiter_id)) = '' THEN 1 ELSE 0 END),
        COUNT(recruiter_id) - COUNT(DISTINCT recruiter_id)
    FROM dbo.dim_recruiter

    UNION ALL

    SELECT
        'dbo.dim_role', 'role_id',
        COUNT(*),
        SUM(CASE WHEN role_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(role_id)) = '' THEN 1 ELSE 0 END),
        COUNT(role_id) - COUNT(DISTINCT role_id)
    FROM dbo.dim_role

    UNION ALL

    SELECT
        'dbo.dim_source', 'source_id',
        COUNT(*),
        SUM(CASE WHEN source_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(source_id)) = '' THEN 1 ELSE 0 END),
        COUNT(source_id) - COUNT(DISTINCT source_id)
    FROM dbo.dim_source

    UNION ALL

    SELECT
        'dbo.fact_application', 'application_id',
        COUNT(*),
        SUM(CASE WHEN application_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(application_id)) = '' THEN 1 ELSE 0 END),
        COUNT(application_id) - COUNT(DISTINCT application_id)
    FROM dbo.fact_application

    UNION ALL

    SELECT
        'dbo.fact_candidate', 'candidate_id',
        COUNT(*),
        SUM(CASE WHEN candidate_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(candidate_id)) = '' THEN 1 ELSE 0 END),
        COUNT(candidate_id) - COUNT(DISTINCT candidate_id)
    FROM dbo.fact_candidate

    UNION ALL

    SELECT
        'dbo.fact_hire_hris', 'hire_id',
        COUNT(*),
        SUM(CASE WHEN hire_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(hire_id)) = '' THEN 1 ELSE 0 END),
        COUNT(hire_id) - COUNT(DISTINCT hire_id)
    FROM dbo.fact_hire_hris

    UNION ALL

    SELECT
        'dbo.fact_offer', 'offer_id',
        COUNT(*),
        SUM(CASE WHEN offer_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(offer_id)) = '' THEN 1 ELSE 0 END),
        COUNT(offer_id) - COUNT(DISTINCT offer_id)
    FROM dbo.fact_offer

    UNION ALL

    SELECT
        'dbo.fact_outreach_event', 'outreach_id',
        COUNT(*),
        SUM(CASE WHEN outreach_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(outreach_id)) = '' THEN 1 ELSE 0 END),
        COUNT(outreach_id) - COUNT(DISTINCT outreach_id)
    FROM dbo.fact_outreach_event

    UNION ALL

    SELECT
        'dbo.fact_requisition', 'req_id',
        COUNT(*),
        SUM(CASE WHEN req_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(req_id)) = '' THEN 1 ELSE 0 END),
        COUNT(req_id) - COUNT(DISTINCT req_id)
    FROM dbo.fact_requisition

    UNION ALL

    SELECT
        'dbo.fact_stage_event', 'stage_event_id',
        COUNT(*),
        SUM(CASE WHEN stage_event_id IS NULL THEN 1 ELSE 0 END),
        SUM(CASE WHEN LTRIM(RTRIM(stage_event_id)) = '' THEN 1 ELSE 0 END),
        COUNT(stage_event_id) - COUNT(DISTINCT stage_event_id)
    FROM dbo.fact_stage_event
) pk
ORDER BY
    duplicate_pk DESC,
    null_pk DESC,
    blank_pk DESC,
    total_rows DESC;

    -- 3b) Composite key uniqueness check for dbo.fact_job_board_daily, 
            -- note that '23' in like 153 is for converting date col to YYYY-MM-DD which is 10 characters long
SELECT
    'dbo.fact_job_board_daily' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN [date] IS NULL OR source_id IS NULL OR campaign_id IS NULL THEN 1 ELSE 0 END) AS null_in_composite_key,
    COUNT(*) - COUNT(DISTINCT CONCAT(CONVERT(varchar(10), [date], 23), '|', source_id, '|', campaign_id)) AS duplicate_composite_key 
FROM dbo.fact_job_board_daily;


/* ============================================================
   Section 4: ORPHAN (FK) CHECKS - UNIONED RESULTS
   Output: one row per relationship with an orphan_count
   ============================================================ */

SELECT
    'fact_requisition -> dim_facility (facility_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                         AS orphan_count
FROM dbo.fact_requisition AS fr
LEFT JOIN dbo.dim_facility AS df
    ON fr.facility_id = df.facility_id
WHERE fr.facility_id IS NOT NULL
  AND df.facility_id IS NULL

UNION ALL

SELECT
    'fact_requisition -> dim_role (role_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                 AS orphan_count
FROM dbo.fact_requisition AS fr
LEFT JOIN dbo.dim_role AS dr
    ON fr.role_id = dr.role_id
WHERE fr.role_id IS NOT NULL
  AND dr.role_id IS NULL

UNION ALL

SELECT
    'fact_requisition -> dim_recruiter (recruiter_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                           AS orphan_count
FROM dbo.fact_requisition AS fr
LEFT JOIN dbo.dim_recruiter AS drec
    ON fr.recruiter_id = drec.recruiter_id
WHERE fr.recruiter_id IS NOT NULL
  AND drec.recruiter_id IS NULL

UNION ALL

SELECT
    'fact_offer -> fact_application (application_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                          AS orphan_count
FROM dbo.fact_offer AS fo
LEFT JOIN dbo.fact_application AS fa
    ON fo.application_id = fa.application_id
WHERE fo.application_id IS NOT NULL
  AND fa.application_id IS NULL

UNION ALL

SELECT
    'fact_application -> fact_candidate (candidate_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                            AS orphan_count
FROM dbo.fact_application AS fa
LEFT JOIN dbo.fact_candidate AS fc
    ON fa.candidate_id = fc.candidate_id
WHERE fa.candidate_id IS NOT NULL
  AND fc.candidate_id IS NULL

UNION ALL

SELECT
    'fact_application -> fact_requisition (req_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                        AS orphan_count
FROM dbo.fact_application AS fa
LEFT JOIN dbo.fact_requisition AS fr
    ON fa.req_id = fr.req_id
WHERE fa.req_id IS NOT NULL
  AND fr.req_id IS NULL

UNION ALL

SELECT
    'fact_application -> dim_source (source_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                     AS orphan_count
FROM dbo.fact_application AS fa
LEFT JOIN dbo.dim_source AS ds
    ON fa.source_id = ds.source_id
WHERE fa.source_id IS NOT NULL
  AND ds.source_id IS NULL

UNION ALL

SELECT
    'fact_application -> dim_campaign (campaign_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                         AS orphan_count
FROM dbo.fact_application AS fa
LEFT JOIN dbo.dim_campaign AS dc
    ON fa.campaign_id = dc.campaign_id
WHERE fa.campaign_id IS NOT NULL
  AND dc.campaign_id IS NULL

UNION ALL

SELECT
    'fact_hire_hris -> fact_application (application_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                              AS orphan_count
FROM dbo.fact_hire_hris AS fh
LEFT JOIN dbo.fact_application AS fa
    ON fh.application_id = fa.application_id
WHERE fh.application_id IS NOT NULL
  AND fa.application_id IS NULL

UNION ALL

SELECT
    'fact_stage_event -> fact_application (application_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                                AS orphan_count
FROM dbo.fact_stage_event AS fse
LEFT JOIN dbo.fact_application AS fa
    ON fse.application_id = fa.application_id
WHERE fse.application_id IS NOT NULL
  AND fa.application_id IS NULL

UNION ALL

SELECT
    'fact_stage_event -> dim_recruiter (recruiter_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                           AS orphan_count
FROM dbo.fact_stage_event AS fse
LEFT JOIN dbo.dim_recruiter AS drec
    ON fse.recruiter_id = drec.recruiter_id
WHERE fse.recruiter_id IS NOT NULL
  AND drec.recruiter_id IS NULL

UNION ALL

SELECT
    'fact_outreach_event -> fact_candidate (candidate_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                               AS orphan_count
FROM dbo.fact_outreach_event AS foe
LEFT JOIN dbo.fact_candidate AS fc
    ON foe.candidate_id = fc.candidate_id
WHERE foe.candidate_id IS NOT NULL
  AND fc.candidate_id IS NULL

UNION ALL

SELECT
    'fact_outreach_event -> dim_recruiter (recruiter_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                              AS orphan_count
FROM dbo.fact_outreach_event AS foe
LEFT JOIN dbo.dim_recruiter AS drec
    ON foe.recruiter_id = drec.recruiter_id
WHERE foe.recruiter_id IS NOT NULL
  AND drec.recruiter_id IS NULL

UNION ALL

SELECT
    'fact_outreach_event -> fact_requisition (req_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                           AS orphan_count
FROM dbo.fact_outreach_event AS foe
LEFT JOIN dbo.fact_requisition AS fr
    ON foe.req_id = fr.req_id
WHERE foe.req_id IS NOT NULL
  AND fr.req_id IS NULL

UNION ALL

SELECT
    'fact_outreach_event -> dim_campaign (campaign_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                            AS orphan_count
FROM dbo.fact_outreach_event AS foe
LEFT JOIN dbo.dim_campaign AS dc
    ON foe.campaign_id = dc.campaign_id
WHERE foe.campaign_id IS NOT NULL
  AND dc.campaign_id IS NULL

UNION ALL

SELECT
    'fact_job_board_daily -> dim_source (source_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                         AS orphan_count
FROM dbo.fact_job_board_daily AS fjbd
LEFT JOIN dbo.dim_source AS ds
    ON fjbd.source_id = ds.source_id
WHERE fjbd.source_id IS NOT NULL
  AND ds.source_id IS NULL

UNION ALL

SELECT
    'fact_job_board_daily -> dim_campaign (campaign_id)' AS tablenames_and_foreign_key,
    COUNT(*)                                             AS orphan_count
FROM dbo.fact_job_board_daily AS fjbd
LEFT JOIN dbo.dim_campaign AS dc
    ON fjbd.campaign_id = dc.campaign_id
WHERE fjbd.campaign_id IS NOT NULL
  AND dc.campaign_id IS NULL;


  
/* ============================================================
   Section 5: Critical Business-Logic Validity Checks
   Goal: Validate lifecycle timelines, SLA coherence, and event integrity
         so executive KPIs are defensible.
   ============================================================ */

-- 5A) Lifecycle and time-order sanity checks (one result set)

-- 5A.1 Requisition lifecycle: close before open (should be 0)

SELECT
    '5A.1'                                      AS check_id,
    'fact_requisition'                          AS table_name,
    'Requisition close_date before open_date'   AS check_description,
    COUNT(*)                                    AS bad_row_count
FROM dbo.fact_requisition
WHERE open_date  IS NOT NULL
  AND close_date IS NOT NULL
  AND close_date < open_date

UNION ALL

-- 5A.2 Requisition should not be Closed with NULL close_date (should be 0 or explainable)

SELECT
    '5A.2'                                      AS check_id,
    'fact_requisition'                          AS table_name,
    'status = Closed but close_date is NULL'    AS check_description,
    COUNT(*)                                    AS bad_row_count
FROM dbo.fact_requisition
WHERE status = 'Closed'
  AND close_date IS NULL

UNION ALL

-- 5A.3 Offer acceptance time should not be negative (should be 0)

SELECT
    '5A.3'                              AS check_id,
    'fact_offer'                        AS table_name,
    'time_to_accept_days is negative'   AS check_description,
    COUNT(*)                            AS bad_row_count
FROM dbo.fact_offer
WHERE time_to_accept_days IS NOT NULL
  AND time_to_accept_days < 0

UNION ALL

-- 5A.4 Hire lifecycle: termination before start (should be 0)

SELECT
    '5A.4'                                  AS check_id,
    'fact_hire_hris'                        AS table_name,
    'termination_date before start_date'    AS check_description,
    COUNT(*)                                AS bad_row_count
FROM dbo.fact_hire_hris
WHERE start_date       IS NOT NULL
  AND termination_date IS NOT NULL
  AND termination_date < start_date

UNION ALL

-- 5A.5 Early attrition flag coherence: attrition flag set but no termination date (should be 0 or explainable)

SELECT
    '5A.5'                                                      AS check_id,
    'fact_hire_hris'                                            AS table_name,
    'early_attrition_90d_flag = 1 but termination_date is NULL' AS check_description,
    COUNT(*)                                                    AS bad_row_count
FROM dbo.fact_hire_hris
WHERE early_attrition_90d_flag = 1
  AND termination_date IS NULL

UNION ALL

-- 5A.6 Campaign date sanity (should be 0)

SELECT
    '5A.6'                          AS check_id,
    'dim_campaign'                  AS table_name,
    'end_date before start_date'    AS check_description,
    COUNT(*)                        AS bad_row_count
FROM dbo.dim_campaign
WHERE start_date IS NOT NULL
  AND end_date   IS NOT NULL
  AND end_date < start_date
ORDER BY
    bad_row_count DESC,
    check_id;

-- 5B) Duplicate business-event detection (stage events)

SELECT TOP (50)
    application_id,
    event_ts,
    from_stage,
    to_stage,
    event_type,

    actor_type,
    recruiter_id,
    COUNT(*) AS dup_count
FROM dbo.fact_stage_event
GROUP BY
    application_id,
    event_ts,
    from_stage,
    to_stage,
    event_type,
    actor_type,
    recruiter_id
HAVING COUNT(*) > 1
ORDER BY dup_count DESC;


-- 5C.1) SLA coherence checks (flags should match numeric comparison)

SELECT
    COUNT(*) AS inconsistent_sla_rows
FROM dbo.fact_stage_event
WHERE sla_days_target IS NOT NULL                                       --avoids false positives.
  AND days_in_previous_stage IS NOT NULL
  AND (
        (
            days_in_previous_stage <= sla_days_target                   --The candidate met SLA by the numbers but the system says they did not
            AND sla_met_flag = 0
        )
     OR 
        (
            days_in_previous_stage > sla_days_target                    -- The candidate exceeded SLA but the system says they did meet it
            AND sla_met_flag = 1
        )
      );

-- 5C.2 breakdown of mismatch types (helps decide whether to trust sla_met_flag)
SELECT
    CASE
        WHEN
            days_in_previous_stage <= sla_days_target 
            AND sla_met_flag = 0 
            THEN 'flag_false_but_should_be_true'
        WHEN 
            days_in_previous_stage >  sla_days_target 
            AND sla_met_flag = 1 
            THEN 'flag_true_but_should_be_false'
        ELSE 
            'other'
    END AS mismatch_type,
    COUNT(*) AS row_count
FROM dbo.fact_stage_event
WHERE sla_days_target IS NOT NULL
  AND days_in_previous_stage IS NOT NULL
  AND (
        (days_in_previous_stage <= sla_days_target AND sla_met_flag = 0)
     OR 
        (days_in_previous_stage >  sla_days_target AND sla_met_flag = 1)
  )
GROUP BY
    CASE
        WHEN 
            days_in_previous_stage <= sla_days_target 
            AND sla_met_flag = 0 
            THEN 'flag_false_but_should_be_true'
        WHEN 
            days_in_previous_stage >  sla_days_target 
            AND sla_met_flag = 1 
            THEN 'flag_true_but_should_be_false'
        ELSE 
            'other'
    END;

--5C.3 Viewing to understand the scale to see how many rows are affected overall

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN sla_met_flag = 1 THEN 1 ELSE 0 END) AS flagged_met,
    SUM(CASE WHEN days_in_previous_stage > sla_days_target THEN 1 ELSE 0 END) AS actually_late
FROM dbo.fact_stage_event
WHERE sla_days_target IS NOT NULL
  AND days_in_previous_stage IS NOT NULL;

--5C.4 Percentage met and percentage late

SELECT
    CAST(100.0 * SUM(CASE WHEN sla_met_flag = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_flagged_met_sla,
    CAST(100.0 * SUM(CASE WHEN days_in_previous_stage > sla_days_target THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_late_based_on_elapsed_time
FROM dbo.fact_stage_event
WHERE sla_days_target IS NOT NULL
  AND days_in_previous_stage IS NOT NULL;


/* ============================================================
   Section 6: Null Rate Snapshot (High-Leverage Fields)
   Goal: Validate KPI readiness only on fact tables that directly 
         feed executive metrics.
   ============================================================ */


-- 6A Requisition KPI readiness
SELECT
    'dbo.fact_requisition' AS table_name,
    COUNT(*) AS total_rows,

    CAST(100.0 * SUM(CASE WHEN open_date IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_open_date,
    CAST(100.0 * SUM(CASE WHEN close_date IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_close_date,

    CAST(100.0 * SUM(CASE WHEN recruiter_id IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_recruiter_id,
    CAST(100.0 * SUM(CASE WHEN LTRIM(RTRIM(recruiter_id)) = '' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_blank_recruiter_id,

    CAST(100.0 * SUM(CASE WHEN role_id IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_role_id,
    CAST(100.0 * SUM(CASE WHEN facility_id IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_facility_id
FROM dbo.fact_requisition;



-- 6B Offer KPI readiness
SELECT
    'dbo.fact_offer' AS table_name,
    COUNT(*) AS total_rows,

    CAST(100.0 * SUM(CASE WHEN offer_date IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_offer_date,

    CAST(100.0 * SUM(CASE WHEN offer_status IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_offer_status,
    CAST(100.0 * SUM(CASE WHEN LTRIM(RTRIM(offer_status)) = '' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_blank_offer_status,

    CAST(100.0 * SUM(CASE WHEN proposed_start_date IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_proposed_start_date,

    SUM(CASE WHEN offer_status = 'Declined' AND (decline_reason IS NULL OR LTRIM(RTRIM(decline_reason))='') THEN 1 ELSE 0 END) AS declined_missing_reason,
    CAST(
        100.0 * SUM(CASE WHEN offer_status = 'Declined' AND (decline_reason IS NULL OR LTRIM(RTRIM(decline_reason))='') THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN offer_status = 'Declined' THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2)) AS percentage_declined_missing_reason
FROM dbo.fact_offer;


--6C HRIS KPI readiness

SELECT
    'dbo.fact_hire_hris' AS table_name,
    COUNT(*) AS total_rows,

    CAST(100.0 * SUM(CASE WHEN start_date IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_start_date,
    CAST(100.0 * SUM(CASE WHEN early_attrition_90d_flag IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_early_attrition_flag
FROM dbo.fact_hire_hris;


--6D SLA KPI readiness
SELECT
    'dbo.fact_stage_event' AS table_name,
    COUNT(*) AS total_rows,

    CAST(100.0 * SUM(CASE WHEN sla_days_target IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_sla_days_target,
    CAST(100.0 * SUM(CASE WHEN sla_met_flag IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_sla_met_flag,
    CAST(100.0 * SUM(CASE WHEN days_in_previous_stage IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS percentage_null_days_in_previous_stage
FROM dbo.fact_stage_event;

