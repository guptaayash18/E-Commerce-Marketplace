-- Mart layer: star schema.
--   dim_date, dim_customer, dim_seller, dim_product
--   fact_orders       grain = one order      (delivery, payment and review metrics)
--   fact_order_items  grain = one item line  (price, freight; carries order flags)
-- Order-level flags (is_late, review_score) are denormalised onto fact_order_items on
-- purpose: it lets seller and category queries run with one join instead of three.

------------------------------------------------------------------------------------
-- dim_date: a date spine covering the full purchase window plus estimated deliveries
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.dim_date CASCADE;
CREATE TABLE mart.dim_date AS
SELECT
    d::date                                     AS date_key,
    extract(year  FROM d)::int                  AS year,
    extract(month FROM d)::int                  AS month,
    to_char(d, 'YYYY-MM')                       AS year_month,
    date_trunc('month', d)::date                AS month_start,
    extract(quarter FROM d)::int                AS quarter,
    extract(isodow FROM d)::int                 AS iso_dow,
    to_char(d, 'Dy')                            AS dow_name,
    extract(isodow FROM d) IN (6, 7)            AS is_weekend
FROM generate_series(DATE '2016-09-01', DATE '2018-12-31', INTERVAL '1 day') AS d;
ALTER TABLE mart.dim_date ADD PRIMARY KEY (date_key);

------------------------------------------------------------------------------------
-- dim_customer: grain = customer_id (one per order in Olist's model).
-- customer_unique_id is the real person; it is what repeat-purchase analysis groups by.
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.dim_customer CASCADE;
CREATE TABLE mart.dim_customer AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.zip_prefix,
    c.city,
    c.state,
    g.lat,
    g.lng
FROM staging.customers c
LEFT JOIN staging.geolocation g ON g.zip_prefix = c.zip_prefix;
ALTER TABLE mart.dim_customer ADD PRIMARY KEY (customer_id);

------------------------------------------------------------------------------------
-- dim_seller
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.dim_seller CASCADE;
CREATE TABLE mart.dim_seller AS
SELECT
    s.seller_id,
    s.zip_prefix,
    s.city,
    s.state,
    g.lat,
    g.lng
FROM staging.sellers s
LEFT JOIN staging.geolocation g ON g.zip_prefix = s.zip_prefix;
ALTER TABLE mart.dim_seller ADD PRIMARY KEY (seller_id);

------------------------------------------------------------------------------------
-- dim_product
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.dim_product CASCADE;
CREATE TABLE mart.dim_product AS
SELECT
    product_id,
    category_pt,
    category_en,
    name_length,
    description_length,
    photos_qty,
    weight_g,
    (length_cm * height_cm * width_cm)  AS volume_cm3
FROM staging.products;
ALTER TABLE mart.dim_product ADD PRIMARY KEY (product_id);

------------------------------------------------------------------------------------
-- fact_orders: one row per order with everything an order-level question needs
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.fact_orders CASCADE;
CREATE TABLE mart.fact_orders AS
WITH items AS (
    SELECT
        order_id,
        count(*)                        AS item_count,
        count(DISTINCT seller_id)       AS seller_count,
        sum(price)                      AS gmv,
        sum(freight_value)              AS freight_total
    FROM staging.order_items
    GROUP BY order_id
),
payments AS (
    SELECT
        order_id,
        sum(payment_value)              AS payment_total,
        max(installments)               AS max_installments,
        -- the payment type that carried the most value on the order
        (array_agg(payment_type ORDER BY payment_value DESC, payment_sequential))[1]
                                        AS primary_payment_type
    FROM staging.order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.purchase_date                     AS purchase_date_key,
    o.purchase_ts,
    o.order_status,
    o.is_delivered,
    o.approved_ts,
    o.carrier_ts,
    o.delivered_ts,
    o.estimated_date,
    o.delivery_days,
    o.late_days,
    o.is_late,
    COALESCE(i.item_count, 0)           AS item_count,
    COALESCE(i.seller_count, 0)         AS seller_count,
    COALESCE(i.gmv, 0)                  AS gmv,
    COALESCE(i.freight_total, 0)        AS freight_total,
    p.payment_total,
    p.max_installments,
    p.primary_payment_type,
    r.review_score,
    r.review_created_ts
FROM staging.orders o
LEFT JOIN items    i ON i.order_id = o.order_id
LEFT JOIN payments p ON p.order_id = o.order_id
LEFT JOIN staging.order_reviews r ON r.order_id = o.order_id;
ALTER TABLE mart.fact_orders ADD PRIMARY KEY (order_id);
ALTER TABLE mart.fact_orders ADD FOREIGN KEY (customer_id)       REFERENCES mart.dim_customer (customer_id);
ALTER TABLE mart.fact_orders ADD FOREIGN KEY (purchase_date_key) REFERENCES mart.dim_date (date_key);

------------------------------------------------------------------------------------
-- fact_order_items: one row per item line
------------------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.fact_order_items CASCADE;
CREATE TABLE mart.fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.customer_id,
    o.purchase_date                     AS purchase_date_key,
    i.price,
    i.freight_value,
    i.shipping_limit_ts,
    -- order-level context copied down so seller/category queries need one join
    o.order_status,
    o.is_delivered,
    o.is_late,
    o.late_days,
    o.delivery_days,
    r.review_score
FROM staging.order_items i
JOIN staging.orders o             ON o.order_id = i.order_id
LEFT JOIN staging.order_reviews r ON r.order_id = i.order_id;
ALTER TABLE mart.fact_order_items ADD PRIMARY KEY (order_id, order_item_id);
ALTER TABLE mart.fact_order_items ADD FOREIGN KEY (order_id)          REFERENCES mart.fact_orders (order_id);
ALTER TABLE mart.fact_order_items ADD FOREIGN KEY (product_id)        REFERENCES mart.dim_product (product_id);
ALTER TABLE mart.fact_order_items ADD FOREIGN KEY (seller_id)         REFERENCES mart.dim_seller (seller_id);
ALTER TABLE mart.fact_order_items ADD FOREIGN KEY (customer_id)       REFERENCES mart.dim_customer (customer_id);
ALTER TABLE mart.fact_order_items ADD FOREIGN KEY (purchase_date_key) REFERENCES mart.dim_date (date_key);
