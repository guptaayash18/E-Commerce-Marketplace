# Defence sheet — how to explain this project in an interview

Read this before any interview where the project is on your CV. Each section gives the plain-English story, the SQL idea behind it, the number, and the trap an interviewer may set.

## Two-minute walkthrough

"I took Olist's public marketplace dataset — about 100k real Brazilian e-commerce orders across nine tables — and built a three-layer PostgreSQL project. Raw tables are loaded as text so nothing fails on load; a staging layer casts types, deduplicates reviews and geolocation, and derives delivery metrics once so every analysis shares one definition of 'late'; fourteen quality checks gate the build; then a star schema with two facts and four dimensions. On top of that I wrote ten analysis queries. The headline finding is that a late delivery makes a 1-star review 7.9 times more likely, and the effect is dose-dependent — 8 to 14 days late means 70% of orders get 1 star. GMV is extremely concentrated: 150 sellers make 53% of revenue. And repeat buying is only 3%, so the marketplace runs on acquisition. I also benchmarked a query rewrite: replacing a correlated subquery with a window function took the cohort query from 980 ms to 204 ms, and without indexes the naive version doesn't finish in 90 seconds."

## The pipeline

| Layer | What it does | Why this way |
|---|---|---|
| raw | 9 tables, every column TEXT, loaded with COPY | a single bad value in a typed column aborts a COPY; text-first means the load always succeeds and typing errors surface in staging, where they can be handled per column |
| staging | casts, NULLIF on empty strings, dedupe, derived columns (delivery_days, late_days, is_late) | one place for every cleaning rule, commented next to the column; every analysis inherits the same definitions |
| quality checks | one SELECT returning 14 rows of (check, observed, passed); the runner stops if any fails | assertions belong in SQL, next to the data; expected values come from profiling the raw files |
| mart | star schema: fact_orders (order grain), fact_order_items (line grain), dim_customer, dim_seller, dim_product, dim_date; PKs and FKs enforced | analysts query one fact and a few dims; FKs prove referential integrity rather than assuming it |
| indexes | secondary indexes on join and filter columns | measured, not assumed: the benchmark drops them and re-times |

Interviewer trap: "Why two fact tables?" Because the questions have two grains. Delivery, payment and review are order-level; price, freight, seller and product are line-level. Storing item rows and summing them for order questions is slower and re-implements the same aggregation in every query. The order-level flags are copied onto the item fact on purpose (denormalisation) so seller and category queries need one join.

## The ten questions

### q01 Late-delivery rate by month, state and overall
Late means delivered after `order_estimated_delivery_date`. Base is the 96,470 delivered orders with a delivery timestamp. `GROUP BY GROUPING SETS ((year_month), (state), ())` produces the three aggregation levels in one pass; `GROUPING()` labels which level a row belongs to. `HAVING count(*) >= 30` drops cells too small to trust.
Number: 6.77% overall; March 2018 18.96%; Alagoas 21.4%.
Trap: "Isn't a monthly late rate affected by orders still in transit at the end of the data?" Yes — the last month (Aug 2018) is truncated; the memo uses March 2018 as the peak, not the tail.

### q02 Review score versus how late
Buckets of days late (on time, 1–3, 4–7, 8–14, 15+) with `CASE`; per bucket the average score and the share of 1-star and 5-star reviews using `count(*) FILTER (WHERE ...)`. The risk ratio column divides each bucket's 1-star rate by the on-time bucket's via `first_value(...) OVER (ORDER BY lateness_bucket)`.
Number: 6.8% → 25.3% → 59.1% → 70.6% → 69.1%; avg review 4.28 vs 2.26.
Trap: "Correlation or causation?" Correlation, and I say so. The dose-response pattern and the size of the effect make a causal reading plausible, but a confounder such as remote regions being both slower and harsher reviewers is not ruled out. That is why the memo's sizing is labelled an estimate.

### q03 Seller GMV concentration
GMV per seller (delivered orders, price only), `ntile(100) OVER (ORDER BY gmv DESC)` assigns each seller a percentile, tiers are built with `CASE`, and `sum(sum(gmv)) OVER (ORDER BY seller_tier)` gives the running cumulative share.
Number: top 1% = 25.9%, top 5% = 53.2%, top 20% = 82.5%, bottom 80% = 17.5%.
Trap: "Why NTILE and not a threshold?" NTILE gives equal-count buckets, which is what "top 5% of sellers" means. A GMV threshold would answer a different question.

### q04 Repeat purchase and cohort retention
The person is `customer_unique_id`, not `customer_id` (Olist issues a new customer_id per order). Cohort month = `min(month) OVER (PARTITION BY customer_unique_id)`; month offset is computed from year and month differences; retention = distinct active people ÷ cohort size. Output is long-form (cohort, offset, retention) which pivots into the classic triangle.
Number: 3.04% repeat; month-1 retention 0.02–0.71%.
Trap: "Why not use customer_id?" Because you would get 0% repeat. Every order has its own customer_id. Knowing this is the single most common mistake on this dataset.

### q05 Freight share by state
Freight ÷ (price + freight) per state, alongside average delivery days and late rate; `rank() OVER (ORDER BY ...)` orders the burden.
Number: Maranhão 20.8% freight, 21.5 days, 17.4% late; SP is lowest on all three.

### q06 Category scorecard
Items joined to dim_product; per category: orders, GMV, share via `sum() OVER ()`, AOV (GMV ÷ non-cancelled orders), average review, cancel/unavailable share, freight share, `rank()` by GMV. Categories with fewer than 100 orders are dropped.
Number: health_beauty R$1.23M (9.4%); watches_gifts AOV R$208.

### q07 Seller scorecard
Item rows collapsed to (seller, order) first so multi-item orders count once per seller; then per seller: delivered orders, GMV, on-time %, average review, average delivery days. `rank() OVER (PARTITION BY state ORDER BY on_time_pct)` finds the worst in each state; `ntile(10)` gives deciles. Only sellers with 50+ delivered orders.
Number: 425 sellers qualify; worst on-time rate 69.9%; network 93.2%.
Trap: "An order with two sellers, one late — who is blamed?" Both, because the customer experiences one delivery. I state this in the query comment. A finer model would use `shipping_limit_ts` per item to attribute the delay; the data supports it and I would do it next.

### q08 Payment mix and instalments
Two blocks in one result via `UNION ALL`: primary payment type mix, then instalment buckets; each with order share (`sum(count(*)) OVER ()`), average order value, average instalments, average review. Primary type = the payment row with the largest value on the order, chosen with `array_agg(payment_type ORDER BY payment_value DESC)[1]` in the mart.
Number: credit card 75.5% of orders, 3.55 instalments; 7–10 instalments AOV R$333.50 vs R$120.21.

### q09 Operational funnel
Four stages counted by timestamp presence (purchased, approved, handed to carrier, delivered); `first_value()` gives share of purchased, `lag()` gives drop from the previous stage.
Number: 99.84% → 98.21% → 97.02%; largest drop approval → carrier (1,623 orders).

### q10 Sizing the late-delivery fix
Labelled estimate. Assumes half of late orders (3,267) become on-time and behave like on-time orders. Effect (a): 1-star reviews avoided = 3,267 × (54.2% − 6.8%) ≈ 1,546. Effect (b): repeat orders gained = 3,178 people whose first order was late × (3.04% − 2.52%) ≈ 16 orders ≈ R$2.3K.
Trap, and the story to tell: my first version compared people who had *ever* had a late order with people who never had. Late-ever customers repeated at 4.66% versus 2.88% — the wrong direction. The reason is selection: a customer with five orders has five chances to hit a late one, so "ever late" is correlated with order count. Conditioning on the first order removes that. Interviewers like this story because it shows you check results that look wrong instead of reporting them.

### Performance benchmark
Query A computes each order's cohort month two ways: a correlated subquery (re-scans the fact table per output row) and `min() OVER (PARTITION BY ...)`. Before timing, the script verifies both return the same 98,207 rows (sorted, hashed). Timing is PostgreSQL's own `EXPLAIN (ANALYZE, FORMAT JSON)` execution time, median of five runs. Query B is a narrow date-range filter, timed with and without the secondary indexes.
Number: 980 ms → 204 ms (4.8×); without indexes the naive query times out at 90 s while the window version runs in 221 ms; index on the date-range query 50.8 ms → 20.5 ms (2.5×).
Trap: "Why did the index barely change the window query?" Because it scans the whole fact table anyway; an index only helps when the planner can avoid most rows. That is the honest answer and the one they want.

## Likely questions, short answers

1. **What is a star schema?** Facts (measurable events at a fixed grain) surrounded by dimensions (who, what, where, when). Queries filter dimensions and aggregate facts.
2. **What is grain?** What one row represents. fact_orders: one order. fact_order_items: one line on an order.
3. **Why a staging layer instead of cleaning in the mart?** So raw is untouched, cleaning is inspectable as a diff, and the mart can be rebuilt without re-loading.
4. **How did you handle duplicates?** Reviews: `row_number() OVER (PARTITION BY order_id ORDER BY answered_ts DESC, created_ts DESC, review_id)` and keep row 1 — deterministic. Geolocation: `GROUP BY zip_prefix` with mean coordinates.
5. **Why deterministic tie-breaks?** So two runs give the same mart. A non-deterministic dedupe can change numbers between runs.
6. **CTE vs subquery?** A CTE names an intermediate result and can be referenced more than once; readability first. Performance-wise PostgreSQL 12+ inlines CTEs unless told not to.
7. **What is a window function?** An aggregate that returns a value per row over a partition without collapsing rows. `sum() OVER (PARTITION BY ...)`, `row_number()`, `lag()`.
8. **Difference between `WHERE` and `HAVING`?** WHERE filters rows before grouping, HAVING filters groups after.
9. **What does `FILTER (WHERE ...)` do?** Conditional aggregation: `count(*) FILTER (WHERE is_late)` counts only late rows. Same as `sum(CASE WHEN ... THEN 1 END)`.
10. **What is `GROUPING SETS`?** Several GROUP BY clauses in one query; `GROUPING(col)` tells you which set a row came from.
11. **How do you know the rewrite is correct?** The benchmark script compares row count and a hash of the sorted rows before timing.
12. **What is EXPLAIN ANALYZE?** Runs the query and shows the actual plan with timings. I used the reported execution time, not Python wall-clock, so client overhead is excluded.
13. **When does an index help?** Selective filters and joins on the indexed column; not for full scans. Costs writes and space.
14. **Why is GMV price-only?** Freight is a pass-through to carriers, not merchandise value. Payment_total is kept separately and reconciles to price + freight.
15. **What are the data's limits?** Two years, one marketplace, Brazil; promise date logic unknown; reviews per order not per item; last month truncated.
16. **What would you do next?** Attribute lateness per item using `shipping_limit_ts` (seller late vs carrier late); join the Marketing Funnel dataset to see whether seller acquisition channel predicts on-time performance; text-mine the review comments.
17. **What is the business recommendation?** Manage the promise date by region and season, put an SLA on approval-to-carrier, and focus seller success on the 150 sellers that carry 53% of GMV.
18. **Where did the data come from and can you share it?** Kaggle, CC BY-NC-SA 4.0. Not redistributed; the README links to it and the loader checks row counts.
19. **How long did it take?** Be honest about your real learning time and that the build was assisted; say what you can now do unaided.
20. **What broke?** The "ever late" confound in q10; the BOM on the translation CSV; duplicate review_ids across different orders; 42 geolocation points outside Brazil.
21. **How would this scale to 100M rows?** Partition facts by month, load incrementally instead of rebuilding, materialise the analysis outputs, move to a columnar warehouse (BigQuery/Snowflake) where these queries are the same SQL.
22. **What is `NULLIF(x, '')`?** Returns NULL when x is the empty string; needed because empty CSV fields arrive as '' in text columns and '' cannot be cast to timestamp.
23. **Why `utf-8-sig` on load?** Strips the byte-order mark that one source file carries; otherwise the first column name gains an invisible character.
24. **Why were 775 orders kept with zero items?** They are real cancelled/unavailable orders and belong in the funnel; dropping them would overstate delivery rates.
25. **What is your test strategy?** Static repo checks, pure-function unit tests, invariant checks on saved results (e.g. funnel is non-increasing, 1-star rate rises with lateness), and live DB checks that skip when no database is present.

## What not to claim

- Do not say "increased", "reduced" or "improved" anything at Olist. Say "found", "showed", "sized", "cut query time".
- Do not call q10 an impact. Call it a sizing with a stated assumption.
- Do not call the dataset synthetic; it is real and anonymised. Do not call it current; it ends in 2018.
