# CV entry

Title | dataset [dates], one objective line stating the task and the stack, three bullets written as plain sentences that open with a business conclusion, name the SQL method as the way it was reached, then give the number. Each line is under 156 characters, with no parentheses, colons, semicolons or first-person pronouns. Replace GITHUB_URL once the repo is pushed. The CV never names Olist; the dataset is credited in the README only.

## Title line

**E-Commerce Marketplace Ops & Growth Analytics | Brazilian Marketplace Orders, Kaggle [Sep 2026 - Sep 2026]** | GITHUB_URL

## Objective line

Built an end-to-end PostgreSQL stack that cleans 1.55M rows via 14 SQL checks into a star schema to find where a 99k-order marketplace loses ratings, sales

## Bullets

- Found late delivery is the top cause of bad reviews by bucketing 96k orders by days late in SQL, as 54% of late orders got 1 star versus 7% on time, p<0.001
- Flagged revenue-concentration risk by ranking 3,095 sellers into percentiles with window functions, which showed the top 5% bring 53% of R$13.2M sales
- Showed growth spend belongs in conversion, not loyalty, since cohort SQL on a 6-table star schema designed from 9 raw tables found only 3% of buyers reorder

## Derivations (defend every number)

| Number | Source | How it is computed |
|---|---|---|
| 1.55M rows, 14 SQL checks, star schema | results/pipeline_log.json; sql/03_quality_checks.sql; sql/04_mart.sql | nine raw tables sum to 1,551,698 rows; 14 UNION ALL checks gate the mart build; 6 mart tables |
| 54% vs 7%, chi-square p<0.001 | results/stat_tests.md | 3,539/6,534 late vs 6,160/89,936 on time; chi-square 15,079, dof 1; risk ratio 7.9x |
| bucketing 96k orders by days late, p<0.001 | sql/analysis/q02; results/stat_tests.md | CASE buckets on late_days, 1-star share with count(*) FILTER; chi-square 15,079, dof 1 |
| top 5% sellers, 53% of R$13.2M | results/q03 row 2; headlines.json → gmv_delivered_brl | ntile(100) over seller GMV, cumulative share with sum(sum(gmv)) OVER (ORDER BY tier); 150 sellers |
| 6-table star schema | sql/04_mart.sql | fact_orders, fact_order_items, dim_customer, dim_seller, dim_product, dim_date |
| 3% of buyers reorder | headlines.json → repeat_customer_rate_pct = 3.04 | people with 2+ non-cancelled orders ÷ all people, grouped on customer_unique_id |
| monthly retention cohorts with window-function SQL | sql/analysis/q04 | cohort month = min(month_start) OVER (PARTITION BY customer_unique_id); retention per month offset |
| spare: 980ms to 204ms | results/perf_benchmark.md | correlated subquery vs window-function rewrite, median of 5 EXPLAIN ANALYZE runs, identical 98,207-row result sets |

## Spare bullets

- Cleaning: Cleaned 1.55M raw rows from 9 tables into a typed staging layer: deduped 100k reviews to 99,441, 1M geo rows to 19k zips; 14 SQL checks gate the build
- Dashboard: Built a self-contained Chart.js dashboard from the saved query results; single HTML file, no server
- Power BI version, only after dashboard/marketplace.pbix exists (docs/power_bi_build.md): Showed growth spend belongs in conversion, not loyalty, since SQL cohorts found only 3% of buyers reorder, and built a Power BI dashboard on the results
- Tuning: Cut the cohort query 980ms to 204ms, 4.8x, by replacing a correlated subquery with a window function, verified with EXPLAIN ANALYZE

## Second validated result available for interviews

Repeat rate after a late first order 2.52% vs 3.04% after an on-time one; difference 0.52 pp, 95% CI 0.12–0.92 pp, two-proportion z = 2.34, p = 0.019. Significant but commercially small; use it to show you distinguish statistical from practical significance.

## Words to avoid on the CV

"increased", "reduced", "improved", "impact" — nothing was deployed at Olist. Use "found", "flagged", "concluded", "validated", "cut query time".
