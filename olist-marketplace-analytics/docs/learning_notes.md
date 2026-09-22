# Learning notes — first principles, decisions, and what went wrong

Written for the author to re-read before interviews. Ordered from foundations upward. Each section ends with the decision taken in this project and, where relevant, the decision that was reversed.

## 1. Why load everything as text first

A CSV cell is a string. `COPY` into a typed column asks PostgreSQL to parse every cell on the way in, and one unparseable cell aborts the whole file. Loading into TEXT columns cannot fail on content, only on structure (column count). Casting then happens in staging, one column at a time, where `NULLIF(col, '')` handles the empty strings that CSVs use for missing values and the cast error, if any, names the column.

Decision: raw = TEXT everywhere. Cost: a second copy of the data (~200 MB) and one more layer.

## 2. Layers are about blame, not tidiness

raw → staging → mart is a chain of custody. If a number looks wrong, the question "is it the source, the cleaning, or the model?" is answered by querying the layer boundary. Cleaning rules live in `02_staging.sql` next to the column they change, so the rule and its reason are never separated.

## 3. Grain before anything else

Every fact table needs a one-sentence answer to "what is one row?" Get it wrong and every sum double-counts. Olist has two natural grains — orders (delivery, payment, review) and item lines (price, freight, seller, product) — so there are two fact tables. Order-level flags are copied onto the item fact deliberately; that is denormalisation with a stated reason (one join instead of three for seller and category queries).

Trap found in the data: `customer_id` is per order, not per person. `customer_unique_id` is the person. Grouping repeat purchases by `customer_id` gives 0% repeat and looks like a bug in the marketplace when it is a bug in the query.

## 4. Deduplication must be deterministic

Reviews: 100,000 rows for 99,441 orders, with some review_ids reused across orders. `DISTINCT ON` or a bare `LIMIT 1` would pick a row arbitrarily and could pick a different one next run. `row_number() OVER (PARTITION BY order_id ORDER BY answered_ts DESC, created_ts DESC, review_id)` names the rule (most recently answered) and breaks ties on a unique column so the output is reproducible.

## 5. Quality checks are SQL, and they gate the build

A check is a query that returns (name, observed, passed). Expected values come from profiling the raw files (`SELECT order_status, count(*) ...`), not from assumption. The pipeline runner refuses to build the mart if any check fails. Fourteen checks, including "775 itemless orders, none delivered", which was first written as a bare count and then tightened to also assert the delivered count is zero, because the claim in the check name was not being tested.

## 6. Window functions are the analyst's core tool

An aggregate collapses rows; a window function keeps the rows and adds context. Everything interesting in this project is a window: cohort month (`min() OVER (PARTITION BY person)`), share of total (`sum() OVER ()`), rank within state, percentile tiers (`ntile`), previous-stage comparison (`lag`), baseline ratio (`first_value`). Learn `PARTITION BY` and `ORDER BY` inside `OVER ()` and most analysis SQL follows.

## 7. GROUPING SETS is three queries in one

`GROUP BY GROUPING SETS ((month), (state), ())` produces month totals, state totals and the grand total in one scan. `GROUPING(col)` returns 1 where the column was rolled up, which is how the `level` label is built. Cheaper than three queries and guarantees the three levels agree.

## 8. What "late" means was decided once

`is_late = delivered_date > estimated_date`, computed in staging, NULL when there is no delivery timestamp. Eight "delivered" orders lack a timestamp; they are excluded from every late-rate base rather than treated as on time. Every analysis, the dashboard and the memo inherit this single definition. If the definition changes (say, a one-day grace), it changes in one place.

## 9. The sizing that was wrong, and why

First version of q10 compared repeat rates for people who had *ever* received a late order against those who never had: 4.66% vs 2.88%. Late customers looked more loyal, which is the opposite of the review evidence.

The error is selection on the outcome. "Ever late" is more likely for people with more orders, and "more orders" is the definition of repeat. The comparison was contaminated by the variable it was trying to explain.

Fix: condition on the *first* order only. Among people whose first delivered order was late, 2.52% ordered again; among those whose first order was on time, 3.04%. Direction now consistent, effect small. The sizing kept both effects and reports honestly that the retention effect is negligible (≈16 orders) and the review effect is the material one (≈1,546 one-star reviews avoided).

General rule learned: when a result contradicts a stronger, more direct result, suspect the conditioning before believing the surprise.

## 10. Performance claims need three things

A control (the naive query), a measurement that excludes client overhead (`EXPLAIN (ANALYZE, FORMAT JSON)` execution time), and proof that the fast version returns the same rows (row count plus a hash of the sorted result). Median of five runs, not the best run.

Result: correlated subquery 980 ms → window function 204 ms with indexes. Without indexes the naive query exceeded 90 s and the window query was unchanged (221 ms), which is itself the lesson: an index helps only when it lets the planner skip most rows; a full-scan query gains nothing from it.

## 11. What the data cannot tell you

- How Olist set the promised date. A rising late rate could mean slower delivery or tighter promises.
- Whether reviews cause churn or just correlate with it; the dataset has no experiment.
- Anything after October 2018.

## 12. Things done differently next time

- Attribute lateness per item using `shipping_limit_ts` so seller delay and carrier delay separate.
- Keep the analysis outputs as materialised views in the database, not only CSVs.
- Load the Marketing Funnel dataset and test whether seller acquisition channel predicts on-time performance.
- Write the quality checks before the staging SQL, not after; the profiling numbers were already known.

## References

- PostgreSQL documentation: window functions (tutorial chapter 3.5), `GROUPING SETS` (7.2.4), `EXPLAIN` (14.1), `COPY` (SQL commands).
- Kimball, *The Data Warehouse Toolkit*: grain, conformed dimensions, denormalisation trade-offs.
- Brazilian E-Commerce Public Dataset by Olist, Kaggle: data schema page.
