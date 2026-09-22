# Olist Marketplace Ops & Growth Analytics (PostgreSQL)

End-to-end SQL analytics project on the Brazilian E-Commerce Public Dataset by Olist:
99,441 real, anonymised marketplace orders (Sep 2016 – Oct 2018) across 9 source tables,
loaded into PostgreSQL, cleaned into a staging layer, modelled as a star schema, and
queried to answer ten operational and growth questions. Every number below comes from a
SQL file in `sql/analysis/` and is saved in `results/`.

![dashboard](docs/dashboard_preview.png)

## Headline findings

| # | Finding | Number | Query |
|---|---|---|---|
| 1 | Late deliveries are a review problem, not just a logistics one | 1-star share **54.2%** when late vs **6.8%** on time (**7.9×**); avg review 2.26 vs 4.28 | q02 |
| 2 | It gets worse the later the parcel is | 8–14 days late → **70.6%** 1-star (**10.3×** on-time risk) | q02 |
| 3 | Lateness is spiky, not steady | Network late rate **6.77%**; **18.96%** in Mar 2018 (7,003 orders); AL **21.4%**, MA **17.4%** | q01 |
| 4 | GMV is concentrated in very few sellers | Top 1% (30 sellers) = **25.9%** of R$13.2M GMV; top 5% = **53.2%**; bottom 80% = 17.5% | q03 |
| 5 | Almost nobody comes back | Repeat-buyer rate **3.04%** of 96,096 people; month-1 cohort retention 0.02–0.71% | q04 |
| 6 | The North-East pays most for the slowest service | MA: freight = **20.8%** of order value, 21.5 days to deliver, 17.4% late | q05 |
| 7 | Instalments buy bigger baskets | 7–10 instalments AOV **R$333** vs R$120 single payment (2.8×); 48.5% of orders pay once | q08 |
| 8 | Ops funnel leaks after approval | 97.02% of orders delivered; largest drop is approval → carrier (1,623 orders, 1.63%) | q09 |
| 9 | Sizing (estimate): halving late deliveries | ≈ **1,546 one-star reviews avoided**; repeat-order gain ≈16 orders (negligible, because repeat is 3%) | q10 |
| 10 | Both headline effects hold up statistically | 1-star rate late vs on-time: chi-square 15,079, p < 0.001, risk ratio 7.9× (95% CIs 53.0–55.4% vs 6.7–7.0%); repeat rate after late vs on-time first order: 0.52 pp gap, p = 0.019 | stat_tests |
| 11 | Query rewrite beats hardware | Cohort query **980 ms → 204 ms (4.8×)** by replacing a correlated subquery with a window function; without indexes the naive version times out (>90 s) | perf |

These are findings and sizings from a public dataset. None of them was deployed inside
Olist, so no line here claims business impact.

## What is in the project

```
data/raw/            9 Kaggle CSVs (not committed; see docs/get_data.md)
sql/00_schemas.sql   raw / staging / mart schemas
sql/01_raw_tables.sql  raw tables, all TEXT (nothing can fail on load)
sql/02_staging.sql   typed + cleaned tables; every rule commented next to its column
sql/03_quality_checks.sql  14 assertions; the mart is not built if any fails
sql/04_mart.sql      star schema: fact_orders, fact_order_items, dim_customer,
                     dim_seller, dim_product, dim_date
sql/05_indexes.sql   secondary indexes
sql/analysis/        q01–q10 business questions + headlines.sql (KPI row)
sql/perf/            benchmark queries and the index-drop script
scripts/             run_pipeline.py, run_analysis.py, perf_benchmark.py,
                     stat_tests.py, build_dashboard.py, run_all.py, db.py
results/             query outputs (CSV), headlines.json, pipeline_log.json,
                     perf_benchmark.md, stat_tests.md
dashboard/           template.html + generated index.html (single file, Chart.js via CDN)
docs/                ERD, data dictionary, insight memo, defence sheet, CV bullets,
                     learning notes
tests/               pytest: repo layout, pure helpers, result invariants, live DB checks
```

Architecture: `raw` (as-loaded text) → `staging` (typed, deduplicated, derived delivery
metrics) → quality gate → `mart` (star schema) → analysis queries → CSV/JSON results →
dashboard and docs. See `docs/erd.md` and `docs/data_dictionary.md`.

## SQL techniques used

CTEs, window functions (`row_number`, `ntile`, `lag`, `first_value`, `min/sum OVER`),
`GROUPING SETS`, `FILTER` aggregates, `array_agg ... ORDER BY` for "type carrying most
value", `generate_series` date spine, deterministic deduplication, foreign-key
constrained star schema, `EXPLAIN (ANALYZE)` benchmarking, index design.

## Cleaning decisions worth knowing

- Reviews: 100,000 rows for 99,441 orders (duplicate review_ids and multi-review orders).
  Kept the most recently answered review per order; ties broken deterministically.
- Geolocation: ~1M rows for 19,015 zip prefixes; collapsed to one mean coordinate per
  prefix and dropped 42 points outside Brazil's bounding box.
- Products: 2 categories missing from the translation file mapped by hand; 610 products
  with no category labelled `unknown`, not dropped (their orders are real GMV).
- Orders: 775 orders have no items — all are cancelled/unavailable/never approved, none
  delivered; kept in `fact_orders` with `gmv = 0`. 8 "delivered" orders lack a delivery
  timestamp and are excluded from lateness metrics (`is_late IS NULL`).
- "Late" = delivered date > estimated delivery date; base for every late-rate figure is
  the 96,470 delivered orders with a delivery timestamp.

## How to run

Requires PostgreSQL 14+ and Python 3.10+.

```bash
# 1. data: download the Kaggle dataset into data/raw/ (docs/get_data.md)
# 2. database
createdb olist                      # or create it in pgAdmin
cp .env.example .env                # then put your password in DATABASE_URL
pip install -r requirements.txt
# 3. everything: load -> clean -> checks -> mart -> queries -> benchmark -> dashboard
python scripts/run_all.py
# 4. checks
ruff check . && pytest -q
```

Individual steps: `python scripts/run_pipeline.py`, `python scripts/run_analysis.py`,
`python scripts/perf_benchmark.py`, `python scripts/stat_tests.py`, `python scripts/build_dashboard.py`.
Open `dashboard/index.html` in a browser (Chart.js loads from a CDN, so the charts need
internet the first time).

Measured on the reference run: raw load 1.55M rows in ~3 s, staging 3.5 s, mart 3.6 s,
all ten analysis queries in under 0.5 s each (`results/pipeline_log.json`,
`results/analysis_summary.md`).

## Honest status

- Built and verified end to end on PostgreSQL 16.15 with the full dataset; all 14
  quality checks pass, 18 tests pass, `ruff` is clean.
- Findings are correlational; the hypothesis tests establish that the differences are not noise, not that lateness causes them. Q10 is a sizing under a stated assumption, labelled as such
  in the SQL, the dashboard and the memo. An earlier version of Q10 was wrong (see
  `docs/learning_notes.md`): conditioning on "ever had a late order" made late customers
  look more loyal, because more orders means more chances to be late.
- Lateness is measured against Olist's own promised date; the dataset does not say how
  that date was set, so a rising late rate could partly reflect tighter promises.
- Review text is loaded but not analysed. The Olist Marketing Funnel dataset (seller
  acquisition) is not joined yet; it is the natural next step.
- The dashboard is a static snapshot rebuilt from `results/`; it has no filters because
  the embedded data is pre-aggregated.

## Data licence

Brazilian E-Commerce Public Dataset by Olist, Kaggle, CC BY-NC-SA 4.0. Raw files are
not redistributed in this repository.
