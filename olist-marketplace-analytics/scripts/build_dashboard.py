"""Build dashboard/index.html from dashboard/template.html and the saved analysis results.

The dashboard embeds the pre-aggregated query results (a few hundred rows) as JSON, so
the file opens offline with no server. Chart.js is loaded from a CDN, so the charts
need an internet connection the first time the page is opened.

Every number on the dashboard comes from results/*.csv and results/headlines.json,
which are produced by run_analysis.py; nothing is recomputed in the browser.

Usage:
    python scripts/build_dashboard.py
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import REPO_ROOT, RESULTS_DIR  # noqa: E402

OUT = REPO_ROOT / "dashboard" / "index.html"
TEMPLATE_PATH = REPO_ROOT / "dashboard" / "template.html"


def read_csv(name: str) -> list[dict]:
    with (RESULTS_DIR / name).open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    for row in rows:
        for key, val in row.items():
            if val is None or val == "":
                row[key] = None
                continue
            try:
                row[key] = float(val) if "." in val else int(val)
            except ValueError:
                pass
    return rows


def main() -> None:
    headlines = json.loads((RESULTS_DIR / "headlines.json").read_text(encoding="utf-8"))
    data = {
        "kpi": headlines,
        "late_by_month": [r for r in read_csv("q01_late_delivery_rate.csv") if r["level"] == "month"],
        "late_by_state": [r for r in read_csv("q01_late_delivery_rate.csv") if r["level"] == "state"],
        "review_vs_late": read_csv("q02_review_score_vs_lateness.csv"),
        "seller_conc": read_csv("q03_seller_gmv_concentration.csv"),
        "cohorts": read_csv("q04_repeat_purchase_and_cohorts.csv"),
        "freight": read_csv("q05_freight_share_by_state.csv"),
        "categories": read_csv("q06_category_performance.csv"),
        "sellers": read_csv("q07_seller_scorecard.csv"),
        "payments": read_csv("q08_payment_mix_and_installments.csv"),
        "funnel": read_csv("q09_order_status_funnel.csv"),
        "sizing": read_csv("q10_sizing_late_delivery_fix.csv")[0],
    }
    data["late_by_month"].sort(key=lambda r: r["key"])
    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    html = template.replace("__DATA__", json.dumps(data, separators=(",", ":")))
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
