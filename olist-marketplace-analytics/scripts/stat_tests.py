"""Hypothesis tests for the two headline comparisons.

  1. 1-star review rate, late vs on-time delivered orders   -> chi-square test of independence
  2. repeat-purchase rate after a late vs on-time FIRST order -> two-proportion z-test

Counts are pulled from the mart with SQL; the tests run in scipy. The point is not the
p-value itself (with 96k orders almost anything is significant) but to state the effect
size with its confidence interval so the CV numbers carry an uncertainty.

Writes results/stat_tests.json and results/stat_tests.md.

Usage:
    python scripts/stat_tests.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from scipy import stats

sys.path.insert(0, str(Path(__file__).resolve().parent))

from db import RESULTS_DIR, connect, fetch_all  # noqa: E402

ONE_STAR_SQL = """
SELECT is_late,
       count(*) FILTER (WHERE review_score = 1) AS one_star,
       count(*)                                  AS orders
FROM mart.fact_orders
WHERE is_delivered AND is_late IS NOT NULL AND review_score IS NOT NULL
GROUP BY is_late ORDER BY is_late
"""

REPEAT_SQL = """
WITH d AS (
    SELECT f.is_late,
           row_number() OVER (PARTITION BY c.customer_unique_id ORDER BY f.purchase_ts, f.order_id) AS seq,
           count(*)     OVER (PARTITION BY c.customer_unique_id) AS orders_per_person
    FROM mart.fact_orders f
    JOIN mart.dim_customer c ON c.customer_id = f.customer_id
    WHERE f.is_delivered AND f.is_late IS NOT NULL
)
SELECT is_late,
       count(*) FILTER (WHERE orders_per_person >= 2) AS repeaters,
       count(*)                                        AS people
FROM d WHERE seq = 1
GROUP BY is_late ORDER BY is_late
"""


def two_by_two(rows: list[tuple]) -> dict[bool, tuple[int, int]]:
    """{is_late: (successes, trials)}"""
    return {bool(r[0]): (int(r[1]), int(r[2])) for r in rows}


def proportion_ci(k: int, n: int, z: float = 1.959964) -> tuple[float, float]:
    """Wilson score interval for a binomial proportion."""
    p = k / n
    denom = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return centre - half, centre + half


def chi_square_test(table: dict[bool, tuple[int, int]]) -> dict:
    (k_on, n_on), (k_late, n_late) = table[False], table[True]
    contingency = [[k_late, n_late - k_late], [k_on, n_on - k_on]]
    chi2, p, dof, _ = stats.chi2_contingency(contingency, correction=False)
    p_late, p_on = k_late / n_late, k_on / n_on
    return {
        "test": "chi-square test of independence (2x2, no continuity correction)",
        "late": {"one_star": k_late, "orders": n_late, "rate": p_late, "ci95": proportion_ci(k_late, n_late)},
        "on_time": {"one_star": k_on, "orders": n_on, "rate": p_on, "ci95": proportion_ci(k_on, n_on)},
        "risk_ratio": p_late / p_on,
        "chi2": chi2,
        "dof": dof,
        "p_value": p,
    }


def two_proportion_z(table: dict[bool, tuple[int, int]]) -> dict:
    (k_on, n_on), (k_late, n_late) = table[False], table[True]
    p_on, p_late = k_on / n_on, k_late / n_late
    pooled = (k_on + k_late) / (n_on + n_late)
    se = math.sqrt(pooled * (1 - pooled) * (1 / n_on + 1 / n_late))
    z = (p_on - p_late) / se
    p = 2 * stats.norm.sf(abs(z))
    diff_se = math.sqrt(p_on * (1 - p_on) / n_on + p_late * (1 - p_late) / n_late)
    diff = p_on - p_late
    return {
        "test": "two-proportion z-test, two-sided",
        "first_order_late": {
            "repeaters": k_late,
            "people": n_late,
            "rate": p_late,
            "ci95": proportion_ci(k_late, n_late),
        },
        "first_order_on_time": {
            "repeaters": k_on,
            "people": n_on,
            "rate": p_on,
            "ci95": proportion_ci(k_on, n_on),
        },
        "difference_pp": diff * 100,
        "difference_ci95_pp": ((diff - 1.959964 * diff_se) * 100, (diff + 1.959964 * diff_se) * 100),
        "z": z,
        "p_value": p,
    }


def fmt_p(p: float) -> str:
    return "< 0.001" if p < 0.001 else f"{p:.3f}"


def _line(label: str, group: dict, k: str, n: str, digits: int) -> str:
    lo, hi = group["ci95"]
    rate = f"{group['rate']:.{digits}%}"
    return f"- {label}: {group[k]:,} of {group[n]:,} = {rate} (95% CI {lo:.{digits}%}–{hi:.{digits}%})"


def render(report: dict) -> str:
    a = report["one_star_late_vs_on_time"]
    b = report["repeat_after_late_vs_on_time_first_order"]
    d_lo, d_hi = b["difference_ci95_pp"]
    lines = [
        "# Hypothesis tests",
        "",
        "## 1. 1-star review rate: late vs on-time delivered orders",
        "",
        _line("late", a["late"], "one_star", "orders", 1),
        _line("on time", a["on_time"], "one_star", "orders", 1),
        f"- risk ratio {a['risk_ratio']:.1f}x; chi-square = {a['chi2']:,.0f}, "
        f"dof = {a['dof']}, p {fmt_p(a['p_value'])}",
        "",
        "## 2. Repeat-purchase rate: late vs on-time first order",
        "",
        _line("first order late", b["first_order_late"], "repeaters", "people", 2),
        _line("first order on time", b["first_order_on_time"], "repeaters", "people", 2),
        f"- difference {b['difference_pp']:.2f} pp (95% CI {d_lo:.2f} to {d_hi:.2f} pp); "
        f"z = {b['z']:.2f}, p {fmt_p(b['p_value'])}",
        "",
        "Both effects are statistically significant at 96k orders; "
        "only the first is large enough to matter commercially.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    with connect() as conn:
        _, one_star_rows = fetch_all(conn, ONE_STAR_SQL)
        _, repeat_rows = fetch_all(conn, REPEAT_SQL)
    report = {
        "one_star_late_vs_on_time": chi_square_test(two_by_two(one_star_rows)),
        "repeat_after_late_vs_on_time_first_order": two_proportion_z(two_by_two(repeat_rows)),
    }
    RESULTS_DIR.mkdir(exist_ok=True)
    (RESULTS_DIR / "stat_tests.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    md = render(report)
    (RESULTS_DIR / "stat_tests.md").write_text(md, encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
