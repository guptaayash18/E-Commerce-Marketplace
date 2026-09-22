-- Data quality gate between staging and mart. One row per check.
-- run_pipeline.py stops before building the mart if any row has passed = false.
-- "expected" values come from the Kaggle dataset page and from profiling the raw files.

WITH checks AS (
    SELECT 'raw.orders has 99,441 rows'                          AS check_name,
           count(*)::text                                        AS observed,
           count(*) = 99441                                      AS passed
    FROM raw.orders
    UNION ALL
    SELECT 'order_id is unique in staging.orders',
           (count(*) - count(DISTINCT order_id))::text,
           count(*) = count(DISTINCT order_id)
    FROM staging.orders
    UNION ALL
    SELECT 'every order has a customer row',
           count(*)::text, count(*) = 0
    FROM staging.orders o
    WHERE NOT EXISTS (SELECT 1 FROM staging.customers c WHERE c.customer_id = o.customer_id)
    UNION ALL
    SELECT 'no order_items row without an order',
           count(*)::text, count(*) = 0
    FROM staging.order_items i
    WHERE NOT EXISTS (SELECT 1 FROM staging.orders o WHERE o.order_id = i.order_id)
    UNION ALL
    SELECT 'no order_items row without a product',
           count(*)::text, count(*) = 0
    FROM staging.order_items i
    WHERE NOT EXISTS (SELECT 1 FROM staging.products p WHERE p.product_id = i.product_id)
    UNION ALL
    SELECT 'no order_items row without a seller',
           count(*)::text, count(*) = 0
    FROM staging.order_items i
    WHERE NOT EXISTS (SELECT 1 FROM staging.sellers s WHERE s.seller_id = i.seller_id)
    UNION ALL
    SELECT 'reviews deduplicated to one per order',
           (count(*) - count(DISTINCT order_id))::text,
           count(*) = count(DISTINCT order_id)
    FROM staging.order_reviews
    UNION ALL
    SELECT 'review_score within 1..5',
           count(*)::text, count(*) = 0
    FROM staging.order_reviews
    WHERE review_score NOT BETWEEN 1 AND 5
    UNION ALL
    SELECT 'no negative price or freight',
           count(*)::text, count(*) = 0
    FROM staging.order_items
    WHERE price < 0 OR freight_value < 0
    UNION ALL
    SELECT 'purchase dates within Sep 2016 .. Oct 2018',
           count(*)::text, count(*) = 0
    FROM staging.orders
    WHERE purchase_date NOT BETWEEN DATE '2016-09-01' AND DATE '2018-10-31'
    UNION ALL
    SELECT 'delivered orders missing delivery date (known: 8)',
           count(*)::text, count(*) <= 8
    FROM staging.orders
    WHERE is_delivered AND delivered_ts IS NULL
    UNION ALL
    SELECT 'one coordinate per zip prefix in staging.geolocation',
           (count(*) - count(DISTINCT zip_prefix))::text,
           count(*) = count(DISTINCT zip_prefix)
    FROM staging.geolocation
    UNION ALL
    SELECT 'every product has an English category label',
           count(*)::text, count(*) = 0
    FROM staging.products
    WHERE category_en IS NULL
    UNION ALL
    SELECT 'orders without any item (known: 775, none delivered)',
           count(*)::text || ' itemless, ' || count(*) FILTER (WHERE is_delivered)::text || ' delivered',
           count(*) = 775 AND count(*) FILTER (WHERE is_delivered) = 0
    FROM staging.orders o
    WHERE NOT EXISTS (SELECT 1 FROM staging.order_items i WHERE i.order_id = o.order_id)
)
SELECT check_name, observed, passed FROM checks;
