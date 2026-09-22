"""Consistency checks across the saved results. These pin the numbers quoted in the
README: if a query changes and the headline moves, a test fails and the docs must be
updated deliberately."""

from __future__ import annotations

import csv
import json

import pytest


def load(repo_root, name):
    with (repo_root / "results" / name).open(encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


@pytest.fixture(scope="module")
def headlines(repo_root):
    path = repo_root / "results" / "headlines.json"
    if not path.exists():
        pytest.skip("results not generated yet; run scripts/run_analysis.py")
    return json.loads(path.read_text(encoding="utf-8"))


def test_headline_invariants(headlines):
    h = headlines
    assert h["orders_total"] == 99441
    assert h["orders_delivered"] <= h["orders_total"]
    assert 0 < h["late_rate_pct"] < 100
    assert h["one_star_pct_late"] > h["one_star_pct_on_time"]
    assert h["avg_review_late"] < h["avg_review_on_time"]
    assert h["top1pct_sellers_gmv_share_pct"] < h["top5pct_sellers_gmv_share_pct"] < 100


def test_q01_overall_row_matches_headline(repo_root, headlines):
    rows = load(repo_root, "q01_late_delivery_rate.csv")
    overall = [r for r in rows if r["level"] == "overall"]
    assert len(overall) == 1
    assert float(overall[0]["late_rate_pct"]) == pytest.approx(headlines["late_rate_pct"], abs=0.01)
    assert int(overall[0]["late_orders"]) == headlines["late_orders"]


def test_q02_dose_response_is_monotone_up_to_two_weeks(repo_root):
    rows = load(repo_root, "q02_review_score_vs_lateness.csv")
    one_star = [float(r["one_star_pct"]) for r in rows]
    # buckets 0..3 (on time, 1-3, 4-7, 8-14 days) must each be worse than the last
    assert one_star[:4] == sorted(one_star[:4])
    assert float(rows[0]["one_star_risk_vs_on_time"]) == 1.0


def test_q03_cumulative_share_ends_at_100(repo_root):
    rows = load(repo_root, "q03_seller_gmv_concentration.csv")
    assert float(rows[-1]["cumulative_share_pct"]) == pytest.approx(100.0, abs=0.1)
    assert sum(int(r["sellers"]) for r in rows) > 0


def test_q09_funnel_is_non_increasing(repo_root):
    rows = load(repo_root, "q09_order_status_funnel.csv")
    orders = [int(r["orders"]) for r in rows]
    assert orders == sorted(orders, reverse=True)
    assert orders[0] == 99441


def test_q10_sizing_is_labelled_estimate(repo_root):
    sql = (repo_root / "sql/analysis/q10_sizing_late_delivery_fix.sql").read_text(encoding="utf-8")
    assert "SIZING" in sql and "not a measured impact" in sql
    row = load(repo_root, "q10_sizing_late_delivery_fix.csv")[0]
    assert float(row["assumed_late_reduction_share"]) == 0.5
    assert int(row["est_one_star_reviews_avoided"]) > 0


def test_perf_benchmark_rewrite_kept_result_set(repo_root):
    path = repo_root / "results" / "perf_benchmark.json"
    if not path.exists():
        pytest.skip("benchmark not run")
    report = json.loads(path.read_text(encoding="utf-8"))
    assert report["rewrite_result_check"]["identical"] is True
    wi = report["with_indexes"]
    assert wi["A_window_function"]["median_ms"] < wi["A_naive_correlated_subquery"]["median_ms"]
