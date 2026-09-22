-- Q8. Payment type mix and how instalment count relates to order value.
-- Two blocks in one result (block column): payment-type mix, then instalment buckets.
-- Base = delivered orders; primary_payment_type = the type carrying most of the value.
WITH base AS (
    SELECT
        primary_payment_type,
        max_installments,
        payment_total,
        review_score
    FROM mart.fact_orders
    WHERE is_delivered AND payment_total IS NOT NULL
)
SELECT
    'payment_type'                                          AS block,
    primary_payment_type                                    AS key,
    count(*)                                                AS orders,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1)      AS order_share_pct,
    round(avg(payment_total), 2)                            AS avg_order_value_brl,
    round(avg(max_installments), 2)                         AS avg_installments,
    round(avg(review_score), 2)                             AS avg_review
FROM base
GROUP BY primary_payment_type

UNION ALL

SELECT
    'installments'                                          AS block,
    CASE
        WHEN max_installments <= 1  THEN '1. single payment'
        WHEN max_installments <= 3  THEN '2. 2-3 instalments'
        WHEN max_installments <= 6  THEN '3. 4-6 instalments'
        WHEN max_installments <= 10 THEN '4. 7-10 instalments'
        ELSE                             '5. 11+ instalments'
    END                                                     AS key,
    count(*),
    round(100.0 * count(*) / sum(count(*)) OVER (), 1),
    round(avg(payment_total), 2),
    round(avg(max_installments), 2),
    round(avg(review_score), 2)
FROM base
GROUP BY 2
ORDER BY block DESC, key;
