"""Unit tests for the pure helper functions; no database needed."""

from __future__ import annotations

import json
from datetime import date
from decimal import Decimal

import db
from perf_benchmark import fmt, render_markdown
from run_analysis import json_safe


def test_load_dotenv_does_not_override_existing_env(tmp_path, monkeypatch):
    env = tmp_path / ".env"
    env.write_text("DATABASE_URL=postgresql://a:b@c/d\n# comment\nOTHER=1\n")
    monkeypatch.setenv("DATABASE_URL", "already-set")
    monkeypatch.delenv("OTHER", raising=False)
    db.load_dotenv(env)
    import os

    assert os.environ["DATABASE_URL"] == "already-set"
    assert os.environ["OTHER"] == "1"


def test_json_safe_handles_decimal_and_date():
    assert json_safe(Decimal("12.50")) == 12.5
    assert json_safe(Decimal("12")) == 12
    assert json_safe(date(2018, 3, 1)) == "2018-03-01"
    assert json_safe("x") == "x"
    json.dumps({"a": json_safe(Decimal("1.5"))})


def test_fmt_reports_timeout():
    assert fmt(None, 90_000) == "timed out (>90 s)"
    assert fmt(1234.5, 90_000) == "1,234.5 ms"


def test_render_markdown_computes_speedups():
    report = {
        "repeats": 5,
        "statement_timeout_ms": 90_000,
        "rewrite_result_check": {"rows": 10, "sha256_16": "abc", "identical": True},
        "with_indexes": {
            "A_naive_correlated_subquery": {"median_ms": 1000.0},
            "A_window_function": {"median_ms": 200.0},
            "B_late_orders_march_2018": {"median_ms": 20.0},
        },
        "without_indexes": {
            "A_naive_correlated_subquery": {"median_ms": None},
            "A_window_function": {"median_ms": 220.0},
            "B_late_orders_march_2018": {"median_ms": 50.0},
        },
    }
    md = render_markdown(report)
    assert "5.0x" in md and "2.5x" in md and "timed out" in md
