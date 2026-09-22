# Data dictionary (mart layer)

All monetary values are BRL. `NULL` in a lateness column means the order was not delivered
or has no delivery timestamp; such rows are excluded from every late-rate figure.

## mart.fact_orders — one row per order (99,441)

| Column | Type | Definition |
|---|---|---|
| order_id | text PK | Olist order id |
| customer_id | text FK | one per order; join to dim_customer |
| purchase_date_key | date FK | purchase timestamp cast to date; join to dim_date |
| purchase_ts | timestamp | order_purchase_timestamp |
| order_status | text | delivered, shipped, canceled, unavailable, invoiced, processing, created, approved |
| is_delivered | bool | order_status = 'delivered' |
| approved_ts / carrier_ts / delivered_ts | timestamp | payment approved / handed to carrier / received by customer; NULL if never reached |
| estimated_date | date | order_estimated_delivery_date (Olist's promise to the customer) |
| delivery_days | int | delivered_ts::date − purchase_ts::date |
| late_days | int | delivered_ts::date − estimated_date; positive = late, negative = early |
| is_late | bool | late_days > 0; NULL when delivered_ts is NULL |
| item_count | int | items on the order (0 for 775 itemless orders) |
| seller_count | int | distinct sellers on the order |
| gmv | numeric | sum of item price, freight excluded |
| freight_total | numeric | sum of item freight_value |
| payment_total | numeric | sum of all payment rows (vouchers + card etc.) |
| max_installments | int | highest instalment count on the order |
| primary_payment_type | text | payment type carrying the largest payment_value |
| review_score | int 1–5 | the deduplicated review for this order |
| review_created_ts | timestamp | when the review survey was created |

## mart.fact_order_items — one row per item line (112,650)

| Column | Type | Definition |
|---|---|---|
| order_id, order_item_id | PK | composite key; order_item_id is the line number |
| product_id, seller_id, customer_id | FK | dimensions |
| purchase_date_key | date FK | copied from the order |
| price | numeric | item price |
| freight_value | numeric | freight charged for this item |
| shipping_limit_ts | timestamp | seller's deadline to hand the item to the carrier |
| order_status, is_delivered, is_late, late_days, delivery_days, review_score | copied from the order | denormalised so seller/category queries need one join |

## Dimensions

| Table | Rows | Key | Notable columns |
|---|---|---|---|
| dim_customer | 99,441 | customer_id | customer_unique_id (the person: 96,096 distinct), state, city, zip_prefix, lat, lng |
| dim_seller | 3,095 | seller_id | state, city, zip_prefix, lat, lng |
| dim_product | 32,951 | product_id | category_en (74 incl. 'unknown'), category_pt, weight_g, volume_cm3, photos_qty |
| dim_date | 852 | date_key | year, month, year_month, month_start, quarter, iso_dow, is_weekend |

## Metric definitions used in the analyses

| Metric | Definition |
|---|---|
| Late-delivery rate | late orders ÷ delivered orders with a delivery timestamp (96,470) |
| GMV | sum of item price on delivered orders (R$13,220,249) |
| AOV (category) | category GMV ÷ non-cancelled orders in the category |
| Repeat-buyer rate | people (customer_unique_id) with ≥2 non-cancelled orders ÷ all people |
| Cohort retention | share of a first-order-month cohort placing an order N months later |
| Seller on-time % | orders where every item arrived by the estimated date ÷ delivered orders for that seller |
| Freight share | freight ÷ (price + freight) |
