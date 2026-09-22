-- Q6. Category scorecard: revenue, share, average order value, review, cancellation
-- and freight burden. Cancellation base = all orders in the category (any status).
-- Rank window makes the top-N reading immediate.
WITH item_level AS (
    SELECT
        p.category_en,
        i.order_id,
        i.price,
        i.freight_value,
        i.order_status,
        i.is_delivered,
        i.review_score
    FROM mart.fact_order_items i
    JOIN mart.dim_product p ON p.product_id = i.product_id
),
per_category AS (
    SELECT
        category_en,
        count(DISTINCT order_id)                             AS orders,
        count(*)                                            AS items,
        sum(price) FILTER (WHERE is_delivered)              AS gmv,
        sum(freight_value) FILTER (WHERE is_delivered)      AS freight,
        avg(review_score) FILTER (WHERE is_delivered)       AS avg_review,
        count(DISTINCT order_id) FILTER (WHERE order_status IN ('canceled', 'unavailable'))
                                                            AS lost_orders
    FROM item_level
    GROUP BY category_en
)
SELECT
    category_en,
    orders,
    items,
    round(gmv, 0)                                           AS gmv_brl,
    round(100.0 * gmv / sum(gmv) OVER (), 2)                AS gmv_share_pct,
    round(gmv / NULLIF(orders - lost_orders, 0), 2)         AS aov_brl,
    round(avg_review, 2)                                    AS avg_review,
    round(100.0 * lost_orders / orders, 2)                  AS cancel_or_unavailable_pct,
    round(100.0 * freight / (gmv + freight), 1)             AS freight_share_pct,
    rank() OVER (ORDER BY gmv DESC)                         AS gmv_rank
FROM per_category
WHERE orders >= 100
ORDER BY gmv DESC;
