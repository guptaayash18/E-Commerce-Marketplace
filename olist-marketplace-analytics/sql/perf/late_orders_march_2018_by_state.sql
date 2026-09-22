-- Benchmark query B: a narrow date-range filter (March 2018, the worst month) joined to
-- customer state. Measures the effect of the purchase_date index on fact_orders.
SELECT
    c.state,
    count(*)                                            AS delivered_orders,
    count(*) FILTER (WHERE f.is_late)                   AS late_orders,
    round(100.0 * count(*) FILTER (WHERE f.is_late) / count(*), 2) AS late_rate_pct
FROM mart.fact_orders f
JOIN mart.dim_customer c ON c.customer_id = f.customer_id
WHERE f.purchase_date_key >= DATE '2018-03-01'
  AND f.purchase_date_key <  DATE '2018-04-01'
  AND f.is_delivered AND f.is_late IS NOT NULL
GROUP BY c.state
ORDER BY late_rate_pct DESC;
