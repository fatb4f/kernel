from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_jsonargparse_minimal.py"), *args],
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
    assert data["command_ref"] == "object:control_plane_inspect_command"
    assert data["emittable_files"] == ["parser.py", "test_control_plane_inspect.py"]


def test_emit_writes_minimal_jsonargparse_project(tmp_path: Path):
    root = Path(__file__).resolve().parent
    output_root = tmp_path / "project"
    result = run("--output-root", str(output_root), cwd=root)
    assert result.returncode == 0, result.stderr

    parser_py = output_root / "parser.py"
    pytest_py = output_root / "test_control_plane_inspect.py"
    manifest = output_root / "realization_manifest.jsonargparse_minimal.json"
    report = output_root / "realization_report.jsonargparse_minimal.json"

    assert parser_py.exists()
    assert pytest_py.exists()
    assert manifest.exists()
    assert report.exists()

    parser_text = parser_py.read_text(encoding="utf-8")
    assert "from jsonargparse import ArgumentParser" in parser_text
    assert "env_prefix='CONTROL_PLANE'" in parser_text
    assert "default_env=True" in parser_text
    assert "choices=['json', 'yaml']" in parser_text

    pytest_text = pytest_py.read_text(encoding="utf-8")
    assert "def test_help_path()" in pytest_text
    assert "def test_invalid_value_path()" in pytest_text

    report_data = json.loads(report.read_text(encoding="utf-8"))
    assert report_data["status"] == "source_surfaces_emitted"
    assert report_data["checks"]["parser_python_syntax"]["ok"] is True
    assert report_data["checks"]["pytest_source_python_syntax"]["ok"] is True
    assert report_data["checks"]["downstream_jsonargparse_runtime"]["status"] in {"ready", "ready_via_uv", "unavailable_in_environment"}
    assert report_data["checks"]["downstream_pytest"]["status"] in {"ok", "failed", "unavailable_in_environment"}
