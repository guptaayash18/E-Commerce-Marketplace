"""Live checks against the built database. Skipped automatically when no database is
reachable, so the suite still runs offline."""

from __future__ import annotations

from db import SQL_DIR, fetch_all


def test_all_quality_checks_pass(db_conn):
    sql = (SQL_DIR / "03_quality_checks.sql").read_text(encoding="utf-8")
    columns, rows = fetch_all(db_conn, sql)
    results = [dict(zip(columns, r, strict=True)) for r in rows]
    failed = [r["check_name"] for r in results if not r["passed"]]
    assert failed == []
    assert len(results) >= 12


def test_mart_grain_and_keys(db_conn):
    _, ((orders, distinct_orders),) = fetch_all(
        db_conn, "SELECT count(*), count(DISTINCT order_id) FROM mart.fact_orders"
    )
    assert orders == distinct_orders == 99441
    _, ((items,),) = fetch_all(db_conn, "SELECT count(*) FROM mart.fact_order_items")
    assert items == 112650
    _, ((orphans,),) = fetch_all(
        db_conn,
        "SELECT count(*) FROM mart.fact_order_items i "
        "LEFT JOIN mart.dim_product p ON p.product_id = i.product_id WHERE p.product_id IS NULL",
    )
    assert orphans == 0


def test_gmv_reconciles_between_facts(db_conn):
    _, ((order_gmv, item_gmv),) = fetch_all(
        db_conn,
        "SELECT (SELECT sum(gmv) FROM mart.fact_orders), (SELECT sum(price) FROM mart.fact_order_items)",
    )
    assert order_gmv == item_gmv
