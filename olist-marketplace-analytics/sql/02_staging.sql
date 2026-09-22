-- Staging layer: one typed, cleaned table per raw table.
-- Every cleaning rule is written next to the column it affects, so the rule and its
-- justification are never separated.

------------------------------------------------------------------------------------
-- customers
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.customers;
CREATE TABLE staging.customers AS
SELECT
    customer_id,
    customer_unique_id,
    -- zip prefixes are 5-digit codes with leading zeros; kept as text so '01037' stays intact
    customer_zip_code_prefix        AS zip_prefix,
    lower(trim(customer_city))      AS city,
    upper(trim(customer_state))     AS state
FROM raw.customers;

------------------------------------------------------------------------------------
-- geolocation: the raw file has ~1M rows for ~19k zip prefixes (one row per address
-- sample). We collapse to one coordinate per prefix (the mean) and drop the 42 rows
-- that fall outside Brazil's bounding box, which are data-entry errors.
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.geolocation;
CREATE TABLE staging.geolocation AS
SELECT
    geolocation_zip_code_prefix                 AS zip_prefix,
    round(avg(geolocation_lat::numeric), 6)     AS lat,
    round(avg(geolocation_lng::numeric), 6)     AS lng,
    count(*)                                    AS sample_rows
FROM raw.geolocation
WHERE geolocation_lat::numeric BETWEEN -33.8 AND 5.3       -- Brazil latitude range
  AND geolocation_lng::numeric BETWEEN -74.0 AND -34.7     -- Brazil longitude range
GROUP BY geolocation_zip_code_prefix;

------------------------------------------------------------------------------------
-- orders: timestamps cast; delivery metrics derived once here so every analysis
-- uses the same definition of "late".
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.orders;
CREATE TABLE staging.orders AS
WITH typed AS (
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp::timestamp                     AS purchase_ts,
        NULLIF(order_approved_at, '')::timestamp                AS approved_ts,
        NULLIF(order_delivered_carrier_date, '')::timestamp     AS carrier_ts,
        NULLIF(order_delivered_customer_date, '')::timestamp    AS delivered_ts,
        order_estimated_delivery_date::timestamp::date          AS estimated_date
    FROM raw.orders
)
SELECT
    order_id,
    customer_id,
    order_status,
    purchase_ts,
    purchase_ts::date                                           AS purchase_date,
    approved_ts,
    carrier_ts,
    delivered_ts,
    estimated_date,
    (order_status = 'delivered')                                AS is_delivered,
    -- days from purchase to the customer receiving the parcel
    (delivered_ts::date - purchase_ts::date)                    AS delivery_days,
    -- positive = arrived after the promised date, negative = arrived early
    (delivered_ts::date - estimated_date)                       AS late_days,
    -- NULL when the order was never delivered (8 delivered orders lack a delivery date)
    CASE WHEN delivered_ts IS NULL THEN NULL
         ELSE delivered_ts::date > estimated_date END           AS is_late
FROM typed;

------------------------------------------------------------------------------------
-- order items
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.order_items;
CREATE TABLE staging.order_items AS
SELECT
    order_id,
    order_item_id::int                  AS order_item_id,
    product_id,
    seller_id,
    shipping_limit_date::timestamp      AS shipping_limit_ts,
    price::numeric(12, 2)               AS price,
    freight_value::numeric(12, 2)       AS freight_value
FROM raw.order_items;

------------------------------------------------------------------------------------
-- order payments: 'not_defined' (3 rows) kept as-is and reported, not silently dropped
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.order_payments;
CREATE TABLE staging.order_payments AS
SELECT
    order_id,
    payment_sequential::int         AS payment_sequential,
    payment_type,
    payment_installments::int       AS installments,
    payment_value::numeric(12, 2)   AS payment_value
FROM raw.order_payments;

------------------------------------------------------------------------------------
-- order reviews: the raw file has 100,000 rows for 99,441 orders. Some orders carry
-- more than one review and some review_ids are reused across orders. Rule: keep the
-- most recently answered review per order; ties broken by creation date then id, so
-- the choice is deterministic. Free-text fields are kept for possible NLP later.
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.order_reviews;
CREATE TABLE staging.order_reviews AS
WITH ranked AS (
    SELECT
        review_id,
        order_id,
        review_score::int                       AS review_score,
        NULLIF(review_comment_title, '')        AS comment_title,
        NULLIF(review_comment_message, '')      AS comment_message,
        review_creation_date::timestamp         AS review_created_ts,
        review_answer_timestamp::timestamp      AS review_answered_ts,
        row_number() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp::timestamp DESC,
                     review_creation_date::timestamp DESC,
                     review_id
        ) AS rn
    FROM raw.order_reviews
)
SELECT review_id, order_id, review_score, comment_title, comment_message,
       review_created_ts, review_answered_ts
FROM ranked
WHERE rn = 1;

------------------------------------------------------------------------------------
-- products: category translated to English. Two categories are missing from the
-- translation file and are mapped by hand; 610 products have no category at all and
-- are labelled 'unknown' rather than dropped, because their orders are still real GMV.
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.products;
CREATE TABLE staging.products AS
SELECT
    p.product_id,
    NULLIF(p.product_category_name, '')                         AS category_pt,
    COALESCE(
        t.product_category_name_english,
        CASE p.product_category_name
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_food_preparers'
            WHEN 'pc_gamer'                                     THEN 'pc_gamer'
        END,
        'unknown'
    )                                                           AS category_en,
    NULLIF(p.product_name_lenght, '')::int                      AS name_length,
    NULLIF(p.product_description_lenght, '')::int               AS description_length,
    NULLIF(p.product_photos_qty, '')::int                       AS photos_qty,
    NULLIF(p.product_weight_g, '')::numeric                     AS weight_g,
    NULLIF(p.product_length_cm, '')::numeric                    AS length_cm,
    NULLIF(p.product_height_cm, '')::numeric                    AS height_cm,
    NULLIF(p.product_width_cm, '')::numeric                     AS width_cm
FROM raw.products p
LEFT JOIN raw.product_category_name_translation t
       ON t.product_category_name = p.product_category_name;

------------------------------------------------------------------------------------
-- sellers
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS staging.sellers;
CREATE TABLE staging.sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix          AS zip_prefix,
    lower(trim(seller_city))        AS city,
    upper(trim(seller_state))       AS state
FROM raw.sellers;
