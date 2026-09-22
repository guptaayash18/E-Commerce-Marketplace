-- Q1. Late-delivery rate overall, by month and by customer state.
-- Late = parcel delivered after order_estimated_delivery_date.
-- Base = delivered orders with a delivery timestamp (96,470 of 99,441 orders).
-- GROUPING SETS gives all three levels from one pass; a level column labels each row.
WITH delivered AS (
    SELECT
        d.year_month,
        c.state,
        f.is_late,
        f.late_days,
        f.delivery_days
    FROM mart.fact_orders f
    JOIN mart.dim_date     d ON d.date_key    = f.purchase_date_key
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    WHERE f.is_delivered AND f.is_late IS NOT NULL
)
SELECT
    CASE
        WHEN GROUPING(year_month) = 0 THEN 'month'
        WHEN GROUPING(state)      = 0 THEN 'state'
        ELSE 'overall'
    END                                                     AS level,
    COALESCE(year_month, state, 'ALL')                      AS key,
    count(*)                                                AS delivered_orders,
    count(*) FILTER (WHERE is_late)                         AS late_orders,
    round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2)
                                                            AS late_rate_pct,
    round(avg(delivery_days), 1)                            AS avg_delivery_days,
    round(avg(late_days) FILTER (WHERE is_late), 1)         AS avg_days_late_when_late
FROM delivered
GROUP BY GROUPING SETS ((year_month), (state), ())
HAVING count(*) >= 30                                       -- drop noisy tiny cells
ORDER BY level, late_rate_pct DESC;
