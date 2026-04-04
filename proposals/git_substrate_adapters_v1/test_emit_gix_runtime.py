from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_gix_runtime.py"), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def test_check_only_reports_runtime_status():
    root = Path(__file__).resolve().parent
    result = run("--check-only", cwd=root)
    data = json.loads(result.stdout if result.stdout.strip() else result.stderr)
    assert data["runtime_kind"] == "gix"
    assert data["status"] in {"ok", "runtime_unavailable"}
    if data["status"] == "ok":
        assert data["build_backend"] == "cargo"
        assert data["crate_surface"] == "gix"
