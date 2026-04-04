from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "control_realize_cli_extension_v2.py"), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def test_check_only_validates_payload():
    root = Path(__file__).resolve().parent
    result = run("--check-only", cwd=root)
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["status"] == "ok"
    assert data["validated_targets"] == 4


def test_realize_emits_unified_projection_tree(tmp_path: Path):
    root = Path(__file__).resolve().parent
    result = run("--root", str(tmp_path), cwd=root)
    assert result.returncode == 0, result.stderr

    bashly_yml = tmp_path / "build" / "bashly" / "control_plane_inspect" / "src" / "bashly.yml"
    bashly_script = tmp_path / "build" / "bashly" / "control_plane_inspect" / "control-plane-inspect"
    parser_py = tmp_path / "build" / "python" / "control_plane_inspect" / "parser.py"
    pytest_file = tmp_path / "build" / "tests" / "python" / "test_control_plane_inspect.py"
    bats_file = tmp_path / "build" / "tests" / "shell" / "control_plane_inspect.bats"
    manifest = tmp_path / "build" / "realization_manifest.json"
    report = tmp_path / "build" / "realization_report.json"

    assert bashly_yml.exists()
    assert bashly_script.exists()
    assert parser_py.exists()
    assert pytest_file.exists()
    assert bats_file.exists()
    assert manifest.exists()
    assert report.exists()

    bats_text = bats_file.read_text(encoding="utf-8")
    assert '@test "alternate format emits yaml"' in bats_text
    assert '--format toml' in bats_text

    pytest_text = pytest_file.read_text(encoding="utf-8")
    assert "PARSER = ROOT / '../../python/control_plane_inspect/parser.py'" in pytest_text
    assert "def test_environment_binding_round_trips()" in pytest_text
    assert "CONTROL_PLANE_PROFILE" in pytest_text

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    assert manifest_data["document_type"] == "realization_manifest"
    assert manifest_data["schema_version"] == "v2"
    assert manifest_data["primary_operator_surface"] == "control_realize_cli_extension_v2.py"
    assert len(manifest_data["targets"]) == 4
    repo_paths = {item["repo_path"] for item in manifest_data["targets"]}
    assert "build/bashly/control_plane_inspect/bashly.yml" in repo_paths
    assert "build/python/control_plane_inspect/parser.py" in repo_paths
    assert "build/tests/shell/control_plane_inspect.bats" in repo_paths
    assert "build/tests/python/test_control_plane_inspect.py" in repo_paths
    for item in manifest_data["targets"]:
        assert item["generated_by"] == "control_realize_cli_extension_v2.py"
        assert item["semantic_inputs"]
        assert item["adapter_family"]
        assert item["projection_role"]

    report_data = json.loads(report.read_text(encoding="utf-8"))
    assert report_data["status"] == "success"
    assert report_data["schema_version"] == "v2"
    assert report_data["primary_operator_surface"] == "control_realize_cli_extension_v2.py"
    assert report_data["backend_reports"]["bashly"]["checks"]["downstream_bashly_generate"]["generate"]["status"] == "ok"
    assert report_data["backend_reports"]["jsonargparse"]["checks"]["downstream_pytest"]["status"] in {"ok", "failed", "unavailable_in_environment"}
