# Getting the data

The raw files are not committed (CC BY-NC-SA 4.0 licence, ~120 MB). Download them once
into `data/raw/`.

## Option A — Kaggle website

1. Sign in to Kaggle and open
   https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
2. Click **Download**, unzip, and copy the nine CSV files into `data/raw/`.

## Option B — Kaggle CLI

```bash
pip install kaggle
# place kaggle.json (API token from your Kaggle account page) in ~/.kaggle/
kaggle datasets download -d olistbr/brazilian-ecommerce -p data/raw --unzip
```

## Expected files

| File | Rows (excl. header) |
|---|---|
| olist_customers_dataset.csv | 99,441 |
| olist_geolocation_dataset.csv | 1,000,163 |
| olist_order_items_dataset.csv | 112,650 |
| olist_order_payments_dataset.csv | 103,886 |
| olist_order_reviews_dataset.csv | 100,000 |
| olist_orders_dataset.csv | 99,441 |
| olist_products_dataset.csv | 32,951 |
| olist_sellers_dataset.csv | 3,095 |
| product_category_name_translation.csv | 71 |

`scripts/run_pipeline.py` prints the row count of each table after loading; compare
against this table. `product_category_name_translation.csv` starts with a UTF-8 BOM and
uses CRLF line endings; the loader handles both.

Optional extension: the Olist Marketing Funnel dataset
(https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist) joins to sellers on
`seller_id`. It is not used yet.
