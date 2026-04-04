from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from git_projection_common import current_codex_root


def run(*args: str, cwd: Path):
    return subprocess.run(
        [sys.executable, str(cwd / "control_realize_git_substrate_adapters_v1.py"), *args],
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
    assert data["validated_targets"] == 3


def test_realize_emits_git_projection_tree(tmp_path: Path):
    root = Path(__file__).resolve().parent
    result = run("--root", str(tmp_path), cwd=root)
    assert result.returncode == 0, result.stderr

    repo_state = tmp_path / "build" / "git" / "codex_home" / "repo_state.json"
    diff_state = tmp_path / "build" / "git" / "codex_home" / "diff_state.json"
    semantic_diff = tmp_path / "build" / "git" / "codex_home" / "semantic_diff.json"
    manifest = tmp_path / "build" / "realization_manifest.json"
    report = tmp_path / "build" / "realization_report.json"

    assert repo_state.exists()
    assert diff_state.exists()
    assert semantic_diff.exists()
    assert manifest.exists()
    assert report.exists()

    repo_state_data = json.loads(repo_state.read_text(encoding="utf-8"))
    assert repo_state_data["document_type"] == "repo_state"
    assert repo_state_data["repository_path"] == str(current_codex_root())
    assert isinstance(repo_state_data["clean"], bool)

    diff_state_data = json.loads(diff_state.read_text(encoding="utf-8"))
    assert diff_state_data["document_type"] == "diff_state"
    assert diff_state_data["comparison_ref"] == "origin/main"
    assert isinstance(diff_state_data["changed_files"], list)

    semantic_diff_data = json.loads(semantic_diff.read_text(encoding="utf-8"))
    assert semantic_diff_data["document_type"] == "semantic_diff"
    assert semantic_diff_data["upstream_diff_ref"] == "object:codex_home_diff_state"
    assert semantic_diff_data["review_basis"]["requires_repo_state_and_diff_state"] is True

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    assert manifest_data["document_type"] == "realization_manifest"
    assert manifest_data["schema_version"] == "v2"
    assert manifest_data["primary_operator_surface"] == "control_realize_git_substrate_adapters_v1.py"
    assert len(manifest_data["targets"]) == 3
    sem_target = next(item for item in manifest_data["targets"] if item["backend"] == "sem")
    assert sem_target["upstream_deterministic_input"] == "object:codex_home_diff_state"

    report_data = json.loads(report.read_text(encoding="utf-8"))
    assert report_data["document_type"] == "realization_report"
    assert report_data["schema_version"] == "v2"
    assert report_data["backend_reports"]["gix"]["targets"]
    assert report_data["backend_reports"]["sem"]["targets"]
    assert report_data["backend_reports"]["gix"]["runtime_check"]["runtime_kind"] == "gix"
    assert report_data["backend_reports"]["sem"]["runtime_check"]["runtime_kind"] == "sem"
    assert report_data["backend_reports"]["sem"]["targets"][0]["runtime_mode"] in {"real_runtime", "minimal_fallback"}
