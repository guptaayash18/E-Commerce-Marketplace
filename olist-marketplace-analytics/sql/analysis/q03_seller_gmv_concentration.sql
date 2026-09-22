-- Q3. How concentrated is GMV across sellers?
-- Sellers are ranked by GMV and sliced into percentile tiers with NTILE(100);
-- a running total gives each tier's share of total marketplace GMV.
-- GMV = sum of item price (freight excluded), delivered orders only.
WITH seller_gmv AS (
    SELECT
        seller_id,
        sum(price)                  AS gmv,
        count(DISTINCT order_id)    AS orders
    FROM mart.fact_order_items
    WHERE is_delivered
    GROUP BY seller_id
),
ranked AS (
    SELECT
        seller_id, gmv, orders,
        ntile(100) OVER (ORDER BY gmv DESC)                 AS pct_rank,
        sum(gmv) OVER ()                                    AS total_gmv
    FROM seller_gmv
),
tiered AS (
    SELECT
        CASE
            WHEN pct_rank <= 1  THEN '1. top 1%'
            WHEN pct_rank <= 5  THEN '2. next 4% (top 5%)'
            WHEN pct_rank <= 20 THEN '3. next 15% (top 20%)'
            ELSE                     '4. bottom 80%'
        END                                                 AS seller_tier,
        gmv, orders, total_gmv
    FROM ranked
)
SELECT
    seller_tier,
    count(*)                                                AS sellers,
    round(sum(gmv), 0)                                      AS gmv_brl,
    round(100.0 * sum(gmv) / max(total_gmv), 1)             AS gmv_share_pct,
    round(100.0 * sum(sum(gmv)) OVER (ORDER BY seller_tier) / max(total_gmv), 1)
                                                            AS cumulative_share_pct,
    sum(orders)                                             AS orders,
    round(avg(gmv), 0)                                      AS avg_gmv_per_seller_brl
FROM tiered
GROUP BY seller_tier
ORDER BY seller_tier;
