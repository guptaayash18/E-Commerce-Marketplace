-- Q10. SIZING (labelled estimate, not a measured impact).
-- Question: if late deliveries were halved, what would change?
-- Two effects are sized, both under the stated assumption that orders moved from late
-- to on-time would behave like today's on-time orders (correlation treated as causal
-- for sizing only; the memo says so explicitly):
--   (a) 1-star reviews avoided = orders moved x (1-star rate late - 1-star rate on time)
--   (b) extra repeat orders    = people whose FIRST order was late, moved
--                                x (repeat rate after on-time first - repeat rate after late first)
-- Effect (b) deliberately conditions on the FIRST order. An earlier version used
-- "ever had a late order", which is confounded: people with more orders have more
-- chances to hit a late one, so "ever late" customers looked MORE loyal. Conditioning on
-- the first order removes that bias.
WITH delivered AS (
    SELECT
        f.order_id,
        c.customer_unique_id,
        f.is_late,
        f.review_score,
        f.gmv,
        row_number() OVER (PARTITION BY c.customer_unique_id ORDER BY f.purchase_ts, f.order_id)
                                                            AS order_seq,
        count(*)     OVER (PARTITION BY c.customer_unique_id)
                                                            AS orders_per_person
    FROM mart.fact_orders f
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    WHERE f.is_delivered AND f.is_late IS NOT NULL
),
review_rates AS (
    SELECT
        count(*) FILTER (WHERE is_late)                                         AS late_orders,
        sum(gmv)  FILTER (WHERE is_late)                                        AS gmv_delivered_late,
        avg((review_score = 1)::int) FILTER (WHERE is_late)                     AS one_star_rate_late,
        avg((review_score = 1)::int) FILTER (WHERE NOT is_late)                 AS one_star_rate_on_time,
        avg(gmv)                                                                AS avg_order_gmv
    FROM delivered
),
first_orders AS (
    SELECT
        count(*) FILTER (WHERE is_late)                                         AS people_first_order_late,
        avg((orders_per_person >= 2)::int) FILTER (WHERE is_late)               AS repeat_rate_first_late,
        avg((orders_per_person >= 2)::int) FILTER (WHERE NOT is_late)           AS repeat_rate_first_on_time
    FROM delivered
    WHERE order_seq = 1
)
SELECT
    0.5                                                     AS assumed_late_reduction_share,
    r.late_orders,
    round(r.gmv_delivered_late)                             AS gmv_delivered_late_brl,
    round(r.late_orders * 0.5)                              AS orders_moved_to_on_time,
    round(100 * r.one_star_rate_late, 1)                    AS one_star_pct_late,
    round(100 * r.one_star_rate_on_time, 1)                 AS one_star_pct_on_time,
    round(r.late_orders * 0.5 * (r.one_star_rate_late - r.one_star_rate_on_time))
                                                            AS est_one_star_reviews_avoided,
    p.people_first_order_late,
    round(p.people_first_order_late * 0.5)                  AS people_moved_to_on_time,
    round(100 * p.repeat_rate_first_late, 2)                AS repeat_pct_after_late_first_order,
    round(100 * p.repeat_rate_first_on_time, 2)             AS repeat_pct_after_on_time_first_order,
    round(p.people_first_order_late * 0.5
          * (p.repeat_rate_first_on_time - p.repeat_rate_first_late))
                                                            AS est_extra_repeat_orders,
    round(r.avg_order_gmv, 2)                               AS avg_order_gmv_brl,
    round(p.people_first_order_late * 0.5
          * (p.repeat_rate_first_on_time - p.repeat_rate_first_late)
          * r.avg_order_gmv)                                AS est_extra_repeat_gmv_brl
FROM review_rates r, first_orders p;
