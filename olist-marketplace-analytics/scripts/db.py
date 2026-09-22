"""Small connection helper shared by every script.

The connection string comes from DATABASE_URL, read from the environment first and
then from a .env file in the repo root. No default password is baked in on purpose:
if nothing is configured the script fails loudly instead of silently connecting to
the wrong database.
"""

from __future__ import annotations

import os
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import psycopg2
import psycopg2.extensions

REPO_ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = REPO_ROOT / "sql"
RESULTS_DIR = REPO_ROOT / "results"
RAW_DIR = REPO_ROOT / "data" / "raw"


def load_dotenv(path: Path = REPO_ROOT / ".env") -> None:
    """Read KEY=VALUE lines from .env into os.environ without overriding real env vars.

    Written by hand instead of pulling in python-dotenv so the project has exactly one
    runtime dependency (psycopg2).
    """
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def database_url() -> str:
    load_dotenv()
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("DATABASE_URL is not set. Copy .env.example to .env and fill in your password.")
    return url


@contextmanager
def connect() -> Iterator[psycopg2.extensions.connection]:
    conn = psycopg2.connect(database_url())
    try:
        yield conn
    finally:
        conn.close()


def run_sql_file(conn: psycopg2.extensions.connection, path: Path) -> float:
    """Execute a whole .sql file inside one transaction and return elapsed seconds."""
    sql = path.read_text(encoding="utf-8")
    start = time.perf_counter()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
    return time.perf_counter() - start


def fetch_all(conn: psycopg2.extensions.connection, sql: str) -> tuple[list[str], list[tuple]]:
    """Run a SELECT and return (column_names, rows)."""
    with conn.cursor() as cur:
        cur.execute(sql)
        columns = [d[0] for d in cur.description]
        rows = cur.fetchall()
    return columns, rows
