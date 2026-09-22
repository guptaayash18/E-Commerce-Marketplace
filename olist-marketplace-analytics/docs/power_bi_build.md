# Building the Power BI dashboard from the saved results

Power BI Desktop is free on Windows (Microsoft Store). Every visual below reads a CSV or JSON already in `results/`, so no database connection is needed.

## Import

1. Get Data → Text/CSV, load these files: `q01_late_delivery_rate.csv`, `q02_review_score_vs_lateness.csv`, `q03_seller_gmv_concentration.csv`, `q04_repeat_purchase_and_cohorts.csv`, `q05_freight_share_by_state.csv`, `q06_category_performance.csv`, `q07_seller_scorecard.csv`, `q09_order_status_funnel.csv`.
2. Get Data → JSON, load `headlines.json`; in Power Query use "Into Table" then "Transpose" and promote the first row to headers so it becomes one row of KPIs.
3. In Power Query, set `late_rate_pct`, `one_star_pct`, `gmv_share_pct`, `retention_pct`, `on_time_pct` to Decimal Number; set `key` in q01 to Text.

## Visuals (one page, 2 rows of KPI cards and 6 visuals)

| Visual | Table | Fields |
|---|---|---|
| 6 KPI cards | headlines | orders_delivered, gmv_delivered_brl, late_rate_pct, one_star_risk_ratio, top5pct_sellers_gmv_share_pct, repeat_customer_rate_pct |
| Line and clustered column | q01 filtered to level = "month" | axis key, column delivered_orders, line late_rate_pct |
| Clustered column | q02 | axis lateness_bucket, values one_star_pct and five_star_pct |
| Bar | q01 filtered to level = "state", top 12 by late_rate_pct | axis key, value late_rate_pct |
| Line and clustered column | q03 | axis seller_tier, column gmv_share_pct, line cumulative_share_pct |
| Matrix | q04 | rows cohort_month, columns month_offset, value retention_pct, conditional colour |
| Table | q07 sorted by on_time_pct ascending | seller_id, seller_state, delivered_orders, gmv_brl, on_time_pct, avg_review |
| Funnel | q09 | category stage, value orders |

Add a slicer on q01 `level` and a slicer on q07 `seller_state`.

## Save and commit

Save as `dashboard/marketplace.pbix`, export a PNG of the page as `docs/power_bi_preview.png`, then:

```
git add dashboard/marketplace.pbix docs/power_bi_preview.png
git commit -m "feat(dashboard): Power BI report built from results/"
git push
```

Then switch the CV bullet to the Power BI wording in docs/cv_bullets.md. Do not claim Power BI on the CV before this commit exists.
