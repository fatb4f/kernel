from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_gix_minimal.py"), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def test_check_only_reports_emittable_files():
    root = Path(__file__).resolve().parent
    result = run("--check-only", cwd=root)
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["status"] == "ok"
    assert data["emittable_files"] == ["repo_state.json", "diff_state.json"]


def test_emit_writes_gix_artifacts(tmp_path: Path):
    root = Path(__file__).resolve().parent
    result = run("--output-root", str(tmp_path / "project"), cwd=root)
    assert result.returncode == 0, result.stderr
    repo_state = tmp_path / "project" / "repo_state.json"
    diff_state = tmp_path / "project" / "diff_state.json"
    assert repo_state.exists()
    assert diff_state.exists()
    repo_data = json.loads(repo_state.read_text(encoding="utf-8"))
    diff_data = json.loads(diff_state.read_text(encoding="utf-8"))
    assert repo_data["document_type"] == "repo_state"
    assert diff_data["document_type"] == "diff_state"
