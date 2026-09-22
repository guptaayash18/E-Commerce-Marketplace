"""Measure the two optimisation stories with EXPLAIN (ANALYZE) instead of wall-clock.

  A. Query rewrite: correlated subquery -> window function (same result set).
  B. Index effect: a narrow date-range query with and without the mart indexes.

Each variant runs REPEATS times; the median execution time is reported so a single
cold-cache outlier cannot flatter or damage the number. The naive query without indexes
is capped by STATEMENT_TIMEOUT_MS and reported as "timed out" if it exceeds it, because
re-scanning the fact table once per row is exactly the failure mode being demonstrated.

Before the timing runs, the script verifies that the naive and rewritten queries return
identical result sets (row count and a hash of sorted rows). A faster query that returns
different rows would not be an optimisation.

Writes results/perf_benchmark.json and results/perf_benchmark.md.

Usage:
    python scripts/perf_benchmark.py
"""

from __future__ import annotations

import hashlib
import json
import statistics
import sys
from pathlib import Path

import psycopg2

sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import RESULTS_DIR, SQL_DIR, connect, fetch_all, run_sql_file  # noqa: E402

PERF_DIR = SQL_DIR / "perf"
REPEATS = 5
STATEMENT_TIMEOUT_MS = 90_000

QUERIES = {
    "A_naive_correlated_subquery": PERF_DIR / "cohort_naive_correlated_subquery.sql",
    "A_window_function": PERF_DIR / "cohort_window_function.sql",
    "B_late_orders_march_2018": PERF_DIR / "late_orders_march_2018_by_state.sql",
}


def result_fingerprint(conn, sql: str) -> tuple[int, str]:
    """Row count plus SHA-256 of the sorted rows, for verifying two queries agree."""
    _, rows = fetch_all(conn, sql)
    canonical = sorted(tuple(str(v) for v in row) for row in rows)
    digest = hashlib.sha256(repr(canonical).encode()).hexdigest()[:16]
    return len(rows), digest


def explain_analyze_ms(conn, sql: str) -> float | None:
    """Return the planner-reported execution time in ms, or None on timeout."""
    with conn.cursor() as cur:
        cur.execute(f"SET statement_timeout = {STATEMENT_TIMEOUT_MS}")
        try:
            cur.execute(f"EXPLAIN (ANALYZE, FORMAT JSON) {sql}")
            plan = cur.fetchone()[0][0]
        except psycopg2.errors.QueryCanceled:
            conn.rollback()
            return None
        finally:
            conn.rollback()
    return float(plan["Execution Time"])


def median_ms(conn, sql: str, repeats: int) -> tuple[float | None, list[float | None]]:
    samples: list[float | None] = []
    for _ in range(repeats):
        t = explain_analyze_ms(conn, sql)
        samples.append(t)
        if t is None:
            # One timeout is enough evidence; repeating it would waste minutes.
            break
    valid = [s for s in samples if s is not None]
    return (statistics.median(valid) if valid and len(valid) == len(samples) else None), samples


def run_suite(conn, label: str) -> dict:
    out: dict = {}
    for name, path in QUERIES.items():
        sql = path.read_text(encoding="utf-8")
        med, samples = median_ms(conn, sql, REPEATS)
        out[name] = {"median_ms": med, "samples_ms": samples}
        shown = f"{med:9.1f} ms" if med is not None else f"timed out (>{STATEMENT_TIMEOUT_MS} ms)"
        print(f"  [{label}] {name:<32} {shown}", flush=True)
    return out


def main() -> None:
    report: dict = {"repeats": REPEATS, "statement_timeout_ms": STATEMENT_TIMEOUT_MS}
    with connect() as conn:
        naive = QUERIES["A_naive_correlated_subquery"].read_text(encoding="utf-8")
        window = QUERIES["A_window_function"].read_text(encoding="utf-8")
        fp_naive = result_fingerprint(conn, naive)
        fp_window = result_fingerprint(conn, window)
        if fp_naive != fp_window:
            raise SystemExit(f"Rewrite changed the result set: {fp_naive} vs {fp_window}")
        report["rewrite_result_check"] = {"rows": fp_naive[0], "sha256_16": fp_naive[1], "identical": True}
        print(f"rewrite check: both queries return {fp_naive[0]:,} identical rows ({fp_naive[1]})")

        print("with indexes (sql/05_indexes.sql applied)")
        run_sql_file(conn, SQL_DIR / "05_indexes.sql")
        report["with_indexes"] = run_suite(conn, "idx")

        print("without secondary indexes")
        run_sql_file(conn, PERF_DIR / "drop_indexes.sql")
        report["without_indexes"] = run_suite(conn, "no-idx")

        # leave the database in its normal indexed state
        run_sql_file(conn, SQL_DIR / "05_indexes.sql")

    RESULTS_DIR.mkdir(exist_ok=True)
    (RESULTS_DIR / "perf_benchmark.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (RESULTS_DIR / "perf_benchmark.md").write_text(render_markdown(report), encoding="utf-8")
    print("wrote results/perf_benchmark.json and results/perf_benchmark.md")


def fmt(ms: float | None, timeout_ms: int) -> str:
    return f"{ms:,.1f} ms" if ms is not None else f"timed out (>{timeout_ms / 1000:.0f} s)"


def render_markdown(report: dict) -> str:
    to = report["statement_timeout_ms"]
    wi, wo = report["with_indexes"], report["without_indexes"]
    lines = [
        "# Performance benchmark",
        "",
        f"Median of {report['repeats']} EXPLAIN (ANALYZE) runs, PostgreSQL execution time. "
        f"Result-set check: naive and window queries return "
        f"{report['rewrite_result_check']['rows']:,} identical rows.",
        "",
        "| Query | With indexes | Without secondary indexes |",
        "|---|---|---|",
    ]
    for name in QUERIES:
        lines.append(f"| {name} | {fmt(wi[name]['median_ms'], to)} | {fmt(wo[name]['median_ms'], to)} |")
    a_naive, a_win = wi["A_naive_correlated_subquery"]["median_ms"], wi["A_window_function"]["median_ms"]
    if a_naive and a_win:
        lines += ["", f"Rewrite speed-up (with indexes): {a_naive / a_win:,.1f}x"]
    b_wi, b_wo = wi["B_late_orders_march_2018"]["median_ms"], wo["B_late_orders_march_2018"]["median_ms"]
    if b_wi and b_wo:
        lines += [f"Index speed-up on query B: {b_wo / b_wi:,.1f}x"]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
