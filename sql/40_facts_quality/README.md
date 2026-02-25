# 40_fact_quality_stability.sql

## Purpose

This fact table measures recruiting outcome quality and stability at a monthly level by source.

While earlier fact tables focus on volume, pipeline, and spend efficiency, this model shifts focus to post-offer outcomes and retention signals.

It is designed to support leadership questions such as:

- Which sources produce hires that remain employed beyond 90 days?
- Which sources experience higher offer decline rates?
- What reasons are driving declined offers?
- Is there a trade-off between volume and long-term stability?

---

## Grain

Two related tables are produced:

### 1. dbo.fact_quality_stability  
**Grain:** month_start_date × source_id  

Contains monthly KPIs including:

- hires  
- early_attrition_hires_90d  
- early_attrition_rate_90d  
- offers  
- declined_offers  
- offer_decline_rate  
- avg_performance_rating_6mo  

Source attributes (source_type, channel, is_paid) are included for reporting convenience.

---

### 2. dbo.fact_offer_decline_reasons  
**Grain:** month_start_date × source_id × decline_reason  

Provides a breakdown of declined offers by reason to support ranked visuals and root-cause analysis.

---

## Data Attribution Logic

- Hires are attributed to source via fact_application.
- Offers are attributed to source via fact_application.
- Month is derived from:
  - start_date (for hires)
  - offer_date (for offers)

This ensures attribution consistency and avoids relying on ambiguous joins.

---

## Design Considerations

- Primary keys enforce grain integrity.
- NULL source_id values are normalized to 'UNKNOWN'.
- Defensive rate calculations prevent divide-by-zero errors.
- A month/source spine prevents row loss when one metric exists without another.

---

## Business Value

This model enables leadership to evaluate not just recruiting throughput, but the quality and sustainability of hiring outcomes.

It supports deeper analysis in Power BI, including:

- Early attrition trends by source
- Offer decline rate comparisons
- Decline reason distribution
- Paid vs non-paid channel stability analysis

---

## Validation

Basic row count and spot-check queries are included at the end of the script to verify build consistency.
