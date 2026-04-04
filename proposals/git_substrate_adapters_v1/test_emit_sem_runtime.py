from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_sem_runtime.py"), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def test_check_only_reports_runtime_status():
    root = Path(__file__).resolve().parent
    result = run("--check-only", cwd=root)
    data = json.loads(result.stdout if result.stdout.strip() else result.stderr)
    assert data["runtime_kind"] == "sem"
    assert data["status"] in {"ok", "runtime_unavailable"}


def test_emit_writes_runtime_artifacts_when_available(tmp_path: Path):
    root = Path(__file__).resolve().parent
    result = run("--output-root", str(tmp_path / "project"), cwd=root)
    if result.returncode != 0:
        data = json.loads(result.stderr)
        assert data["message"] == "sem runtime unavailable"
        return
    semantic_diff = tmp_path / "project" / "semantic_diff.json"
    review_basis = tmp_path / "project" / "review_basis.json"
    assert semantic_diff.exists()
    assert review_basis.exists()
    semantic_data = json.loads(semantic_diff.read_text(encoding="utf-8"))
    review_basis_data = json.loads(review_basis.read_text(encoding="utf-8"))
    assert semantic_data["document_type"] == "semantic_diff"
    assert semantic_data["backend"] == "sem"
    assert review_basis_data["document_type"] == "review_basis"
