"""Rebuild the whole database from the raw CSVs.

Order of operations:
    00_schemas.sql      -> create raw / staging / mart schemas
    01_raw_tables.sql   -> raw tables, all TEXT
    COPY                -> load the 9 CSVs from data/raw/
    02_staging.sql      -> typed, cleaned, deduplicated tables
    03_quality_checks.sql -> assertions; the run stops if any check fails
    04_mart.sql         -> star schema (facts + dimensions)
    05_indexes.sql      -> indexes on the mart

Every step is logged with its elapsed time and the resulting row counts, and the log is
written to results/pipeline_log.json so the README numbers are reproducible.

Usage:
    python scripts/run_pipeline.py
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import RAW_DIR, RESULTS_DIR, SQL_DIR, connect, fetch_all, run_sql_file  # noqa: E402

# CSV file -> raw table. Order does not matter for the load; it matters for readability.
RAW_FILES = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_name_translation",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def load_raw(conn) -> dict[str, int]:
    """COPY each CSV into its raw table. Returns {table: row_count}."""
    counts: dict[str, int] = {}
    for filename, table in RAW_FILES.items():
        path = RAW_DIR / filename
        if not path.exists():
            raise SystemExit(f"Missing {path}. Download the Kaggle dataset first (see docs/get_data.md).")
        start = time.perf_counter()
        with conn.cursor() as cur, path.open("r", encoding="utf-8-sig", newline="") as fh:
            # utf-8-sig strips the BOM that product_category_name_translation.csv carries.
            # CSV mode handles the quoted multi-line review comments correctly.
            cur.copy_expert(f"COPY raw.{table} FROM STDIN WITH (FORMAT csv, HEADER true)", fh)
        conn.commit()
        _, rows = fetch_all(conn, f"SELECT COUNT(*) FROM raw.{table}")
        counts[table] = rows[0][0]
        log(f"  raw.{table:<36} {counts[table]:>9,} rows  {time.perf_counter() - start:5.1f}s")
    return counts


def table_counts(conn, schema: str) -> dict[str, int]:
    _, tables = fetch_all(
        conn,
        f"SELECT table_name FROM information_schema.tables "
        f"WHERE table_schema = '{schema}' ORDER BY table_name",
    )
    counts = {}
    for (name,) in tables:
        _, rows = fetch_all(conn, f"SELECT COUNT(*) FROM {schema}.{name}")
        counts[name] = rows[0][0]
    return counts


def run_quality_checks(conn) -> list[dict]:
    """03_quality_checks.sql is a single SELECT returning one row per check."""
    sql = (SQL_DIR / "03_quality_checks.sql").read_text(encoding="utf-8")
    columns, rows = fetch_all(conn, sql)
    results = [dict(zip(columns, row, strict=True)) for row in rows]
    failed = [r for r in results if not r["passed"]]
    for r in results:
        status = "PASS" if r["passed"] else "FAIL"
        log(f"  [{status}] {r['check_name']:<48} observed={r['observed']}")
    if failed:
        raise SystemExit(f"{len(failed)} quality check(s) failed; mart not built.")
    return results


def main() -> None:
    pipeline_log: dict = {"steps": {}, "raw_counts": {}, "staging_counts": {}, "mart_counts": {}}
    with connect() as conn:
        for step in ("00_schemas.sql", "01_raw_tables.sql"):
            elapsed = run_sql_file(conn, SQL_DIR / step)
            pipeline_log["steps"][step] = round(elapsed, 3)
            log(f"{step:<24} {elapsed:6.2f}s")

        log("COPY raw CSVs")
        start = time.perf_counter()
        pipeline_log["raw_counts"] = load_raw(conn)
        pipeline_log["steps"]["copy_raw"] = round(time.perf_counter() - start, 3)

        elapsed = run_sql_file(conn, SQL_DIR / "02_staging.sql")
        pipeline_log["steps"]["02_staging.sql"] = round(elapsed, 3)
        log(f"{'02_staging.sql':<24} {elapsed:6.2f}s")
        pipeline_log["staging_counts"] = table_counts(conn, "staging")

        log("03_quality_checks.sql")
        pipeline_log["quality_checks"] = run_quality_checks(conn)

        for step in ("04_mart.sql", "05_indexes.sql"):
            elapsed = run_sql_file(conn, SQL_DIR / step)
            pipeline_log["steps"][step] = round(elapsed, 3)
            log(f"{step:<24} {elapsed:6.2f}s")
        pipeline_log["mart_counts"] = table_counts(conn, "mart")

    RESULTS_DIR.mkdir(exist_ok=True)
    out = RESULTS_DIR / "pipeline_log.json"
    out.write_text(json.dumps(pipeline_log, indent=2, default=str), encoding="utf-8")
    log(f"wrote {out}")


if __name__ == "__main__":
    main()
