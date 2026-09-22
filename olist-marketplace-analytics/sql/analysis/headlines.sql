-- Headline KPIs in one row. run_analysis.py writes this to results/headlines.json,
-- which the README, insight memo and dashboard all read from, so every number quoted
-- in prose traces back to exactly one query.
WITH delivered AS (
    SELECT f.*, c.customer_unique_id
    FROM mart.fact_orders f
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    WHERE f.is_delivered AND f.is_late IS NOT NULL
),
worst_month AS (
    SELECT d.year_month, round(100.0 * avg(is_late::int), 2) AS late_rate_pct
    FROM delivered f JOIN mart.dim_date d ON d.date_key = f.purchase_date_key
    GROUP BY d.year_month HAVING count(*) >= 30
    ORDER BY late_rate_pct DESC LIMIT 1
),
worst_state AS (
    SELECT c.state, round(100.0 * avg(is_late::int), 2) AS late_rate_pct
    FROM delivered f JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    GROUP BY c.state HAVING count(*) >= 100
    ORDER BY late_rate_pct DESC LIMIT 1
),
seller_conc AS (
    SELECT round(100.0 * sum(gmv) FILTER (WHERE pct_rank <= 5) / sum(gmv), 1) AS top5pct_share,
           round(100.0 * sum(gmv) FILTER (WHERE pct_rank <= 1) / sum(gmv), 1) AS top1pct_share
    FROM (
        SELECT seller_id, sum(price) AS gmv, ntile(100) OVER (ORDER BY sum(price) DESC) AS pct_rank
        FROM mart.fact_order_items WHERE is_delivered GROUP BY seller_id
    ) s
),
repeat AS (
    SELECT round(100.0 * avg((n >= 2)::int), 2) AS repeat_rate_pct
    FROM (
        SELECT c.customer_unique_id, count(*) AS n
        FROM mart.fact_orders f JOIN mart.dim_customer c ON c.customer_id = f.customer_id
        WHERE f.order_status NOT IN ('canceled', 'unavailable')
        GROUP BY c.customer_unique_id
    ) p
)
SELECT
    (SELECT count(*) FROM mart.fact_orders)                                     AS orders_total,
    (SELECT count(*) FROM mart.fact_orders WHERE is_delivered)                  AS orders_delivered,
    (SELECT count(*) FROM delivered)                                            AS orders_delivered_with_date,
    (SELECT count(DISTINCT customer_unique_id) FROM mart.dim_customer)          AS customers_unique,
    (SELECT count(*) FROM mart.dim_seller)                                      AS sellers,
    (SELECT count(*) FROM mart.dim_product)                                     AS products,
    (SELECT count(DISTINCT category_en) FROM mart.dim_product)                  AS categories,
    (SELECT min(purchase_date_key) FROM mart.fact_orders)                       AS first_order_date,
    (SELECT max(purchase_date_key) FROM mart.fact_orders)                       AS last_order_date,
    round((SELECT sum(gmv) FROM delivered))                                     AS gmv_delivered_brl,
    round((SELECT avg(gmv) FROM delivered), 2)                                  AS avg_order_gmv_brl,
    round(100.0 * (SELECT count(*) FROM delivered WHERE is_late)
          / (SELECT count(*) FROM delivered), 2)                                AS late_rate_pct,
    (SELECT count(*) FROM delivered WHERE is_late)                              AS late_orders,
    round((SELECT avg(delivery_days) FROM delivered), 1)                        AS avg_delivery_days,
    round((SELECT avg(late_days) FROM delivered WHERE is_late), 1)              AS avg_days_late_when_late,
    round((SELECT avg(review_score) FROM delivered), 2)                         AS avg_review_all,
    round((SELECT avg(review_score) FROM delivered WHERE NOT is_late), 2)       AS avg_review_on_time,
    round((SELECT avg(review_score) FROM delivered WHERE is_late), 2)           AS avg_review_late,
    round(100.0 * (SELECT avg((review_score = 1)::int) FROM delivered WHERE NOT is_late), 1)
                                                                                AS one_star_pct_on_time,
    round(100.0 * (SELECT avg((review_score = 1)::int) FROM delivered WHERE is_late), 1)
                                                                                AS one_star_pct_late,
    round((SELECT avg((review_score = 1)::int) FROM delivered WHERE is_late)
          / (SELECT avg((review_score = 1)::int) FROM delivered WHERE NOT is_late), 1)
                                                                                AS one_star_risk_ratio,
    (SELECT year_month FROM worst_month)                                        AS worst_month,
    (SELECT late_rate_pct FROM worst_month)                                     AS worst_month_late_rate_pct,
    (SELECT state FROM worst_state)                                             AS worst_state,
    (SELECT late_rate_pct FROM worst_state)                                     AS worst_state_late_rate_pct,
    (SELECT top1pct_share FROM seller_conc)                                     AS top1pct_sellers_gmv_share_pct,
    (SELECT top5pct_share FROM seller_conc)                                     AS top5pct_sellers_gmv_share_pct,
    (SELECT repeat_rate_pct FROM repeat)                                        AS repeat_customer_rate_pct;
