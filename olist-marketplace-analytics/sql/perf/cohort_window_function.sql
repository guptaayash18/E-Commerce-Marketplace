-- Benchmark query A, rewritten: the same cohort month via a window function, which
-- computes every person's first month in one pass over the joined rows.
SELECT
    c.customer_unique_id,
    f.order_id,
    d.month_start AS order_month,
    min(d.month_start) OVER (PARTITION BY c.customer_unique_id) AS cohort_month
FROM mart.fact_orders f
JOIN mart.dim_customer c ON c.customer_id = f.customer_id
JOIN mart.dim_date     d ON d.date_key    = f.purchase_date_key
WHERE f.order_status NOT IN ('canceled', 'unavailable');
