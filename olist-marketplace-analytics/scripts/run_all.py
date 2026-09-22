"""Reproduce every artefact in one go: pipeline -> analysis -> benchmark -> dashboard.

Usage:
    python scripts/run_all.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
STEPS = ["run_pipeline.py", "run_analysis.py", "perf_benchmark.py", "stat_tests.py", "build_dashboard.py"]


def main() -> None:
    for step in STEPS:
        print(f"\n=== {step} ===", flush=True)
        subprocess.run([sys.executable, str(SCRIPTS / step)], check=True)


if __name__ == "__main__":
    main()
