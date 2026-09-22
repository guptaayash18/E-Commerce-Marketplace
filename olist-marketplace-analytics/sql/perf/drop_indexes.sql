-- Removes exactly the secondary indexes created in sql/05_indexes.sql, so the benchmark
-- can measure query time without them. Primary keys are kept.
DROP INDEX IF EXISTS mart.ix_fact_orders_customer;
DROP INDEX IF EXISTS mart.ix_fact_orders_purchase_date;
DROP INDEX IF EXISTS mart.ix_fact_orders_status;
DROP INDEX IF EXISTS mart.ix_fact_items_seller;
DROP INDEX IF EXISTS mart.ix_fact_items_product;
DROP INDEX IF EXISTS mart.ix_fact_items_customer;
DROP INDEX IF EXISTS mart.ix_fact_items_purchase_date;
DROP INDEX IF EXISTS mart.ix_dim_customer_unique;
DROP INDEX IF EXISTS mart.ix_dim_customer_state;
DROP INDEX IF EXISTS mart.ix_dim_seller_state;
DROP INDEX IF EXISTS mart.ix_dim_product_category;
