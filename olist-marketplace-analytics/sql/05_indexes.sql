-- Secondary indexes on the mart. Primary keys (created in 04_mart.sql) already index
-- the key columns; these cover the join and filter paths the analysis queries use.
-- sql/perf/drop_indexes.sql removes exactly this set so the benchmark can measure
-- their effect.

CREATE INDEX IF NOT EXISTS ix_fact_orders_customer      ON mart.fact_orders (customer_id);
CREATE INDEX IF NOT EXISTS ix_fact_orders_purchase_date ON mart.fact_orders (purchase_date_key);
CREATE INDEX IF NOT EXISTS ix_fact_orders_status        ON mart.fact_orders (order_status);

CREATE INDEX IF NOT EXISTS ix_fact_items_seller         ON mart.fact_order_items (seller_id);
CREATE INDEX IF NOT EXISTS ix_fact_items_product        ON mart.fact_order_items (product_id);
CREATE INDEX IF NOT EXISTS ix_fact_items_customer       ON mart.fact_order_items (customer_id);
CREATE INDEX IF NOT EXISTS ix_fact_items_purchase_date  ON mart.fact_order_items (purchase_date_key);

CREATE INDEX IF NOT EXISTS ix_dim_customer_unique       ON mart.dim_customer (customer_unique_id);
CREATE INDEX IF NOT EXISTS ix_dim_customer_state        ON mart.dim_customer (state);
CREATE INDEX IF NOT EXISTS ix_dim_seller_state          ON mart.dim_seller (state);
CREATE INDEX IF NOT EXISTS ix_dim_product_category      ON mart.dim_product (category_en);

ANALYZE mart.fact_orders;
ANALYZE mart.fact_order_items;
ANALYZE mart.dim_customer;
ANALYZE mart.dim_seller;
ANALYZE mart.dim_product;
ANALYZE mart.dim_date;
