"""Run every analysis query and save the results.

For each sql/analysis/qNN_*.sql file:
    results/qNN_*.csv        full result set
sql/analysis/headlines.sql -> results/headlines.json (single KPI row)
results/analysis_summary.md lists every query with its row count and elapsed time.

Usage:
    python scripts/run_analysis.py
"""

from __future__ import annotations

import csv
import json
import sys
import time
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import RESULTS_DIR, SQL_DIR, connect, fetch_all  # noqa: E402

ANALYSIS_DIR = SQL_DIR / "analysis"


def json_safe(value):
    """Convert Decimal/date values so json.dumps accepts them without losing precision."""
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def main() -> None:
    RESULTS_DIR.mkdir(exist_ok=True)
    summary_rows: list[tuple[str, int, float]] = []

    with connect() as conn:
        for path in sorted(ANALYSIS_DIR.glob("q*.sql")):
            sql = path.read_text(encoding="utf-8")
            start = time.perf_counter()
            columns, rows = fetch_all(conn, sql)
            elapsed = time.perf_counter() - start
            out = RESULTS_DIR / f"{path.stem}.csv"
            with out.open("w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh, lineterminator="\n")
                writer.writerow(columns)
                writer.writerows(rows)
            summary_rows.append((path.stem, len(rows), elapsed))
            print(f"{path.stem:<40} {len(rows):>6} rows  {elapsed * 1000:7.0f} ms", flush=True)

        columns, rows = fetch_all(conn, (ANALYSIS_DIR / "headlines.sql").read_text(encoding="utf-8"))
        headlines = {col: json_safe(val) for col, val in zip(columns, rows[0], strict=True)}
        headlines["generated_at"] = datetime.now().isoformat(timespec="seconds")
        (RESULTS_DIR / "headlines.json").write_text(json.dumps(headlines, indent=2), encoding="utf-8")
        print(f"{'headlines':<40} {len(headlines):>6} keys")

    lines = [
        "# Analysis run summary",
        "",
        f"Generated {headlines['generated_at']}",
        "",
        "| Query | Rows | Time |",
        "|---|---|---|",
    ]
    for name, n, secs in summary_rows:
        lines.append(f"| {name} | {n:,} | {secs * 1000:,.0f} ms |")
    (RESULTS_DIR / "analysis_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote results/*.csv, results/headlines.json, results/analysis_summary.md")


if __name__ == "__main__":
    main()
