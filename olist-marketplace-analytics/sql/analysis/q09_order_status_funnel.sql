-- Q9. Operational funnel: purchase -> approved -> handed to carrier -> delivered.
-- A stage counts when its timestamp exists, regardless of final status, so the funnel
-- shows where orders stall. Drop-off is measured against the previous stage.
WITH stages AS (
    SELECT 1 AS step, 'purchased'          AS stage, count(*) AS orders FROM mart.fact_orders
    UNION ALL
    SELECT 2, 'approved',                          count(*) FROM mart.fact_orders WHERE approved_ts  IS NOT NULL
    UNION ALL
    SELECT 3, 'handed_to_carrier',                 count(*) FROM mart.fact_orders WHERE carrier_ts   IS NOT NULL
    UNION ALL
    SELECT 4, 'delivered_to_customer',             count(*) FROM mart.fact_orders WHERE delivered_ts IS NOT NULL
)
SELECT
    step,
    stage,
    orders,
    round(100.0 * orders / first_value(orders) OVER (ORDER BY step), 2)
                                                            AS pct_of_purchased,
    lag(orders) OVER (ORDER BY step) - orders               AS dropped_from_prev_stage,
    round(100.0 * (lag(orders) OVER (ORDER BY step) - orders)
          / lag(orders) OVER (ORDER BY step), 2)            AS drop_off_pct
FROM stages
ORDER BY step;
