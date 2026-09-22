-- Q4. Repeat purchase rate and monthly retention cohorts.
-- A person is customer_unique_id (customer_id changes per order in Olist's model).
-- Cohort = month of a person's first order; retention = share of the cohort that
-- placed another order N months later. Output is long-form (one row per cohort x
-- month offset); month_offset 0 is the cohort size itself.
WITH orders_per_person AS (
    SELECT
        c.customer_unique_id,
        f.order_id,
        d.month_start                                       AS order_month,
        min(d.month_start) OVER (PARTITION BY c.customer_unique_id)
                                                            AS cohort_month
    FROM mart.fact_orders f
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    JOIN mart.dim_date     d ON d.date_key    = f.purchase_date_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
),
activity AS (
    SELECT DISTINCT
        customer_unique_id,
        cohort_month,
        (extract(year  FROM order_month) - extract(year  FROM cohort_month)) * 12
      + (extract(month FROM order_month) - extract(month FROM cohort_month))
                                                            AS month_offset
    FROM orders_per_person
),
cohort_size AS (
    SELECT cohort_month, count(DISTINCT customer_unique_id) AS cohort_customers
    FROM activity
    GROUP BY cohort_month
)
SELECT
    to_char(a.cohort_month, 'YYYY-MM')                      AS cohort_month,
    a.month_offset::int                                     AS month_offset,
    s.cohort_customers,
    count(DISTINCT a.customer_unique_id)                    AS active_customers,
    round(100.0 * count(DISTINCT a.customer_unique_id) / s.cohort_customers, 2)
                                                            AS retention_pct
FROM activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
WHERE s.cohort_customers >= 100                             -- skip the sparse 2016 cohorts
GROUP BY a.cohort_month, a.month_offset, s.cohort_customers
ORDER BY a.cohort_month, a.month_offset;
