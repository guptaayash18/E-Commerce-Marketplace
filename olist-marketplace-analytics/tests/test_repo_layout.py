"""Static checks on the repo itself: files exist, layers are ordered, nothing leaks."""

from __future__ import annotations

import re

PIPELINE_FILES = [
    "sql/00_schemas.sql",
    "sql/01_raw_tables.sql",
    "sql/02_staging.sql",
    "sql/03_quality_checks.sql",
    "sql/04_mart.sql",
    "sql/05_indexes.sql",
]
ANALYSIS_COUNT = 10


def test_pipeline_files_exist_in_order(repo_root):
    for rel in PIPELINE_FILES:
        assert (repo_root / rel).is_file(), rel


def test_ten_analysis_queries_with_headers(repo_root):
    files = sorted((repo_root / "sql" / "analysis").glob("q*.sql"))
    assert len(files) == ANALYSIS_COUNT
    for i, path in enumerate(files, start=1):
        first = path.read_text(encoding="utf-8").lstrip().splitlines()[0]
        assert first.startswith(f"-- Q{i}."), f"{path.name} must start with '-- Q{i}.'"


def test_indexes_and_drop_script_match(repo_root):
    create_sql = (repo_root / "sql/05_indexes.sql").read_text()
    drop_sql = (repo_root / "sql/perf/drop_indexes.sql").read_text()
    created = set(re.findall(r"CREATE INDEX IF NOT EXISTS (\w+)", create_sql))
    dropped = set(re.findall(r"DROP INDEX IF EXISTS mart\.(\w+)", drop_sql))
    assert created == dropped


def test_no_secrets_committed(repo_root):
    assert not (repo_root / ".env").exists() or ".env" in (repo_root / ".gitignore").read_text()
    for path in repo_root.rglob("*"):
        if path.suffix in {".py", ".sql", ".md", ".html", ".txt"} and ".git" not in path.parts:
            text = path.read_text(encoding="utf-8", errors="ignore")
            assert "postgresql://postgres:" not in text or "YOUR_PASSWORD" in text, path
