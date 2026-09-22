"""Shared fixtures. Tests never need network access or secrets; the database tests
skip themselves when no DATABASE_URL is configured or the server is unreachable."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture(scope="session")
def db_conn():
    """A live connection to the built database, or skip."""
    import db
    import psycopg2

    try:
        url = db.database_url()
    except SystemExit:
        pytest.skip("DATABASE_URL not configured")
    try:
        conn = psycopg2.connect(url)
    except psycopg2.OperationalError as exc:
        pytest.skip(f"database unreachable: {exc}")
    yield conn
    conn.close()
