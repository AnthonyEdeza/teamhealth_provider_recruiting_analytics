# Spend & Sourcing Effectiveness (SQL)

This folder contains SQL logic used to evaluate the effectiveness of recruiting spend across sources and campaigns.

The goal of this analysis is to connect marketing investment to recruiting outcomes in a way that supports operational and financial decision-making.

---

## Business Context

Recruiting and finance leaders frequently need visibility into questions such as:

- Which sourcing channels generate the most hires?
- What is cost per application and cost per hire?
- Are paid channels producing measurable return?
- How does campaign spend translate into actual starts?

Raw marketing and recruiting tables exist in separate domains:
- Daily job board spend activity
- Applications and offers
- HRIS hire records

This folder introduces a purpose-built fact table that aligns these datasets at a consistent reporting grain.

---

## Current Tables

### `30_fact_spend_effectiveness.sql`

Builds a monthly spend effectiveness fact table at the grain of:

> **Month × Source × Campaign**

The table includes:

- Impressions, clicks, and apply starts
- Applications created in ATS
- Offers generated
- Hires (based on start date)
- Total spend
- Cost per application
- Cost per hire

---

## Key Design Notes

- Spend data is aggregated from daily job board records to monthly totals.
- Recruiting outcomes are linked using `application_id` as the bridge key.
- Attribution is first-touch based on the application’s recorded source and campaign.
- Source and campaign IDs are normalized to an explicit `UNKNOWN` value to maintain primary key integrity and prevent data loss from null attribution.
- Cost metrics use defensive divide logic to avoid zero-denominator errors.
- The table is pre-aggregated for direct use in Power BI.

This analysis prioritizes clarity and traceability over advanced attribution modeling.

---

## Intended Use

This table supports:

- CFO review of recruiting ROI
- Paid vs organic channel comparison
- Campaign-level performance analysis
- Executive dashboard KPI tracking

More advanced time intelligence (YoY trends, rolling averages) is handled in Power BI rather than embedded in SQL.

---

## Relationship to Other Folders

- Complements `/10_facts` (enterprise health metrics)
- Complements `/20_risk_and_bottlenecks` (operational exposure)
- Uses conformed dimensions created earlier in the pipeline

---

## Notes

This implementation focuses on building a defensible monthly reporting mart.  
It does not attempt multi-touch attribution or predictive ROI modeling.
