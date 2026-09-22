-- Q5. Freight as a share of what the customer pays, by customer state, with delivery
-- time alongside. Shows which regions pay the most for the slowest service.
-- Base = delivered orders with a delivery timestamp.
WITH per_order AS (
    SELECT
        c.state,
        f.gmv,
        f.freight_total,
        f.delivery_days,
        f.is_late
    FROM mart.fact_orders f
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    WHERE f.is_delivered AND f.is_late IS NOT NULL AND f.gmv > 0
)
SELECT
    state,
    count(*)                                                AS delivered_orders,
    round(sum(gmv), 0)                                      AS gmv_brl,
    round(avg(gmv + freight_total), 2)                      AS avg_order_value_brl,
    round(100.0 * sum(freight_total) / sum(gmv + freight_total), 1)
                                                            AS freight_share_pct,
    round(avg(delivery_days), 1)                            AS avg_delivery_days,
    round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 1)
                                                            AS late_rate_pct,
    rank() OVER (ORDER BY sum(freight_total) / sum(gmv + freight_total) DESC)
                                                            AS freight_burden_rank
FROM per_order
GROUP BY state
HAVING count(*) >= 100
ORDER BY freight_share_pct DESC;
