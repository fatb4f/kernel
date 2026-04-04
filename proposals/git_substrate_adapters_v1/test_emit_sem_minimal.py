from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_sem_minimal.py"), *args],
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
    assert data["emittable_files"] == ["semantic_diff.json"]
    assert data["upstream_diff_ref"] == "object:codex_home_diff_state"


def test_emit_writes_semantic_diff_artifact(tmp_path: Path):
    root = Path(__file__).resolve().parent
    result = run("--output-root", str(tmp_path / "project"), cwd=root)
    assert result.returncode == 0, result.stderr
    semantic_diff = tmp_path / "project" / "semantic_diff.json"
    assert semantic_diff.exists()
    semantic_data = json.loads(semantic_diff.read_text(encoding="utf-8"))
    assert semantic_data["document_type"] == "semantic_diff"
    assert semantic_data["upstream_diff_ref"] == "object:codex_home_diff_state"
