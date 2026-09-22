-- Benchmark query A, naive form: "cohort month" (first order month per person) found
-- with a correlated subquery that re-scans the fact table once per output row.
-- Same result set as cohort_window_function.sql; kept only to measure the difference.
SELECT
    c.customer_unique_id,
    f.order_id,
    d.month_start AS order_month,
    (
        SELECT min(d2.month_start)
        FROM mart.fact_orders f2
        JOIN mart.dim_customer c2 ON c2.customer_id = f2.customer_id
        JOIN mart.dim_date     d2 ON d2.date_key    = f2.purchase_date_key
        WHERE c2.customer_unique_id = c.customer_unique_id
          AND f2.order_status NOT IN ('canceled', 'unavailable')
    ) AS cohort_month
FROM mart.fact_orders f
JOIN mart.dim_customer c ON c.customer_id = f.customer_id
JOIN mart.dim_date     d ON d.date_key    = f.purchase_date_key
WHERE f.order_status NOT IN ('canceled', 'unavailable');
