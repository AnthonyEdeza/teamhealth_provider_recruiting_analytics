# Recruiter Capacity (SQL)

This folder contains SQL logic used to measure recruiter workload and capacity utilization over time.

The goal is to quantify whether recruiter load is balanced and sustainable, using a monthly “open requisitions at month end” snapshot approach.

---

## Business Context

Recruiting leadership and operations teams commonly need visibility into:

- How many open requisitions each recruiter is carrying
- Who is above or below target capacity
- Whether workload is concentrated among a small subset of recruiters
- How workload trends month over month

Raw requisition records do not answer these questions directly at the recruiter level, so this folder introduces a purpose-built reporting fact table.

---

## Current Tables

### `50_fact_recruiter_capacity.sql`

Builds a monthly recruiter capacity fact table at the grain of:

> **Month × Recruiter**

The table includes:

- Open requisitions per recruiter (month-end snapshot proxy)
- Recruiter capacity target (from `dim_recruiter.capacity_target_open_reqs`)
- Capacity gap (open reqs minus target)
- Over-capacity flag (open reqs > target)

---

## Key Definitions

### Open requisitions at month end
A requisition is treated as open at month end if:

- `open_date` is on or before the month end date  
- and (`close_date` is NULL or after the month end date)

This reconstructs a point-in-time workload view without requiring a daily snapshot table.

---

## Intended Use

This table is designed for direct use in Power BI, including:

- Recruiter workload tables (open reqs vs target)
- Over-capacity counts and percent over capacity
- Workload concentration / Pareto visuals
- Month-over-month workload trends

---

## Validation

The SQL script includes basic validation queries, including:

- row count check
- grain uniqueness check (no duplicate month × recruiter buckets)
- spot-check of highest workload rows in the latest month
