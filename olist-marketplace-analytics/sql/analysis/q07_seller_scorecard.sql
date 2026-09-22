-- Q7. Seller scorecard for sellers with at least 50 delivered orders.
-- On-time rate and review are order-level (an order's lateness belongs to every seller
-- on it, which is how the marketplace's SLA treats multi-seller orders).
-- Rank within state finds the weakest sellers in each region for account managers.
WITH seller_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        max(i.is_late::int)         AS is_late,
        max(i.review_score)         AS review_score,
        max(i.delivery_days)        AS delivery_days,
        sum(i.price)                AS gmv
    FROM mart.fact_order_items i
    WHERE i.is_delivered AND i.is_late IS NOT NULL
    GROUP BY i.seller_id, i.order_id
),
scored AS (
    SELECT
        s.seller_id,
        d.state                                             AS seller_state,
        count(*)                                            AS delivered_orders,
        round(sum(gmv), 0)                                  AS gmv_brl,
        round(100.0 * (count(*) - sum(is_late)) / count(*), 1)
                                                            AS on_time_pct,
        round(avg(review_score), 2)                         AS avg_review,
        round(avg(delivery_days), 1)                        AS avg_delivery_days
    FROM seller_orders s
    JOIN mart.dim_seller d ON d.seller_id = s.seller_id
    GROUP BY s.seller_id, d.state
    HAVING count(*) >= 50
)
SELECT
    seller_id,
    seller_state,
    delivered_orders,
    gmv_brl,
    on_time_pct,
    avg_review,
    avg_delivery_days,
    rank() OVER (PARTITION BY seller_state ORDER BY on_time_pct ASC)
                                                            AS worst_on_time_rank_in_state,
    ntile(10) OVER (ORDER BY on_time_pct)                   AS on_time_decile,
    round(100.0 * gmv_brl / sum(gmv_brl) OVER (), 2)        AS gmv_share_pct
FROM scored
ORDER BY on_time_pct ASC, gmv_brl DESC;
