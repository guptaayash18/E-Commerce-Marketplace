-- Q2. Does lateness hurt reviews, and does it get worse the later the parcel is?
-- Buckets of days late show the dose-response; 'on time or early' is the control.
-- Base = delivered orders with a review (every order carries exactly one review after
-- staging dedupe).
WITH scored AS (
    SELECT
        CASE
            WHEN NOT is_late          THEN '0. on time or early'
            WHEN late_days BETWEEN 1  AND 3  THEN '1. late 1-3 days'
            WHEN late_days BETWEEN 4  AND 7  THEN '2. late 4-7 days'
            WHEN late_days BETWEEN 8  AND 14 THEN '3. late 8-14 days'
            ELSE                             '4. late 15+ days'
        END                                                 AS lateness_bucket,
        review_score
    FROM mart.fact_orders
    WHERE is_delivered AND is_late IS NOT NULL AND review_score IS NOT NULL
)
SELECT
    lateness_bucket,
    count(*)                                                AS orders,
    round(avg(review_score), 2)                             AS avg_review_score,
    round(100.0 * count(*) FILTER (WHERE review_score = 1) / count(*), 1)
                                                            AS one_star_pct,
    round(100.0 * count(*) FILTER (WHERE review_score = 5) / count(*), 1)
                                                            AS five_star_pct,
    -- how many times more likely a 1-star review is than in the on-time group
    round(
        (count(*) FILTER (WHERE review_score = 1))::numeric / count(*)
        / first_value((count(*) FILTER (WHERE review_score = 1))::numeric / count(*))
              OVER (ORDER BY lateness_bucket),
        1)                                                  AS one_star_risk_vs_on_time
FROM scored
GROUP BY lateness_bucket
ORDER BY lateness_bucket;
