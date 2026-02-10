# Staffing Risk & Bottleneck Analysis (SQL)

This folder contains SQL logic used to identify and monitor **staffing risk** across specialties and regions.

The tables in this folder are designed to support operational decision-making by highlighting where recruiting demand is aging, concentrated, or at risk of impacting service delivery.

---

## Business Context

Leadership and recruiting operations teams frequently need to answer questions such as:

- Which specialties and regions have the highest backlog of open requisitions?
- Where are requisitions aging beyond acceptable thresholds?
- Are certain roles systematically harder to staff?
- Do rural locations experience different staffing pressures than non-rural sites?

Raw recruiting transaction tables do not answer these questions directly.  
This folder introduces purpose-built fact tables that translate requisition lifecycle data into **risk-oriented metrics** suitable for dashboards and operational reviews.

---

## Current Tables

### `20_fact_staffing_risk.sql`

Builds a **monthly staffing risk fact table** at the grain of:

> **Month × Region × Specialty**

This table supports:
- Heatmaps showing staffing exposure by specialty and region
- Trend analysis of open requisitions over time
- Identification of aging backlog beyond a defined risk threshold
- Rural vs non-rural staffing comparisons
- Analysis of hard-to-fill role concentration

#### Key Design Notes
- The dataset does not include a daily snapshot table.  
  Open requisitions are reconstructed using `open_date` and `close_date` logic.
- A requisition is considered *open at month end* if:
  - `open_date` is on or before the month end
  - and `close_date` is null or after the month end
- Staffing risk is defined using a configurable age threshold (e.g., 60 days) to keep assumptions explicit and adjustable.
- Region and specialty are mapped to conformed dimensions, with explicit `Unknown` handling to prevent data loss from incomplete records.

The resulting table is intentionally pre-aggregated to align with Power BI visuals and reduce report-level complexity.

---

## Intended Use

These tables are designed to be:
- Consumed directly by Power BI dashboards
- Used in operational reviews and staffing discussions
- Extended over time as additional risk indicators or thresholds are introduced

This folder focuses on **risk visibility**, not predictive modeling or optimization.

---

## Relationship to Other Folders

- Complements `/10_facts`, which provides enterprise-level health indicators
- Feeds executive dashboard sections focused on staffing risk and bottlenecks
- Uses conformed dimensions created earlier in the SQL pipeline

---

## Notes

This analysis emphasizes clarity, traceability, and defensible assumptions over advanced statistical techniques.  
More complex time intelligence and comparisons (e.g., YoY deltas) are intentionally handled in Power BI rather than embedded in SQL.
