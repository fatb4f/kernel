from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "emit_bashly_minimal.py"), *args],
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
    assert data["emittable_files"] == ["src/bashly.yml", "src/root_command.sh"]


def test_emit_writes_minimal_bashly_project(tmp_path: Path):
    root = Path(__file__).resolve().parent
    output_root = tmp_path / "project"
    result = run("--output-root", str(output_root), cwd=root)
    assert result.returncode == 0, result.stderr

    bashly_yml = output_root / "src" / "bashly.yml"
    root_partial = output_root / "src" / "root_command.sh"
    generated_script = output_root / "control-plane-inspect"
    manifest = output_root / "realization_manifest.bashly_minimal.json"
    report = output_root / "realization_report.bashly_minimal.json"

    assert bashly_yml.exists()
    assert root_partial.exists()
    assert generated_script.exists()
    assert manifest.exists()
    assert report.exists()

    bashly_text = bashly_yml.read_text(encoding="utf-8")
    assert "name: control-plane-inspect" in bashly_text
    assert "long: --format" in bashly_text
    assert "allowed:" in bashly_text
    assert "- json" in bashly_text
    assert "- yaml" in bashly_text

    root_text = root_partial.read_text(encoding="utf-8")
    assert 'format="${args[--format]:-json}"' in root_text
    assert 'kind":"control_plane_inspect' in root_text

    report_data = json.loads(report.read_text(encoding="utf-8"))
    assert report_data["status"] == "source_surfaces_emitted"
    assert report_data["checks"]["root_partial_shell_syntax"]["ok"] is True
    assert report_data["checks"]["downstream_bashly_generate"]["discovery"]["status"] in {"ready", "unavailable_in_environment"}
    assert report_data["checks"]["downstream_bashly_generate"]["generate"]["status"] in {"ok", "unavailable_in_environment", "failed"}

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    emitted_paths = {item["repo_path"] for item in manifest_data["emitted"]}
    assert "src/bashly.yml" in emitted_paths
    assert "src/root_command.sh" in emitted_paths
    if report_data["checks"]["downstream_bashly_generate"]["generate"]["status"] == "ok":
        assert "control-plane-inspect" in emitted_paths
