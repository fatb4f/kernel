#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from git_projection_common import (
    GitProjectionError,
    command_exists,
    load_json,
    normalize_objects,
    parse_repository_ref,
    write_json,
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-gix-runtime",
        description="Emit repo_state and diff_state using the crate-backed gix runtime helper.",
    )
    parser.add_argument("--model", default="canonical_semantic_model.git.example.json")
    parser.add_argument("--output-root", default="realized/git_substrate/codex_home")
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args(argv)


def helper_paths(base: Path) -> tuple[Path, Path]:
    helper_root = base / "gix_runtime_helper"
    manifest = helper_root / "Cargo.toml"
    binary = helper_root / "target" / "debug" / "gix_runtime_helper"
    return manifest, binary


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    base = Path(__file__).resolve().parent
    model_path = (base / args.model).resolve() if not Path(args.model).is_absolute() else Path(args.model)
    output_root = (base / args.output_root).resolve() if not Path(args.output_root).is_absolute() else Path(args.output_root)
    try:
        manifest, binary = helper_paths(base)
        cargo_bin = "cargo" if command_exists("cargo") else None
        gix_bin = "gix" if command_exists("gix") else None
        status = "ok" if cargo_bin and manifest.exists() else "runtime_unavailable"
        payload = {
            "status": status,
            "runtime_kind": "gix",
            "build_backend": "cargo",
            "crate_surface": "gix",
            "cargo_bin": cargo_bin,
            "gix_cli_present": gix_bin is not None,
            "helper_manifest": str(manifest),
            "helper_manifest_exists": manifest.exists(),
            "helper_binary": str(binary),
            "helper_binary_exists": binary.exists(),
            "missing": [
                name
                for name, ok in (
                    ("cargo", cargo_bin is not None),
                    ("gix_runtime_helper_manifest", manifest.exists()),
                )
                if not ok
            ],
        }
        if args.check_only:
            print(json.dumps(payload, indent=2))
            return 0 if status == "ok" else 2
        if status != "ok":
            raise GitProjectionError("gix runtime unavailable")

        model = load_json(model_path)
        objects = normalize_objects(model)
        repo_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "repo_state_surface")
        diff_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "diff_state_surface")

        repo_path = str(parse_repository_ref(str(repo_obj.attributes["repository_ref"])))
        comparison_ref = str(diff_obj.attributes["comparison_ref"])
        helper_output_root = output_root / "gix_runtime_helper"
        result = subprocess.run(
            [
                cargo_bin,
                "run",
                "--quiet",
                "--manifest-path",
                str(manifest),
                "--",
                "--repo-path",
                repo_path,
                "--comparison-ref",
                comparison_ref,
                "--output-root",
                str(helper_output_root),
            ],
            cwd=base,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise GitProjectionError(f"gix helper failed: {result.stderr.strip() or result.stdout.strip()}")
        helper_json = json.loads(result.stdout)

        repo_state = {
            "document_type": "repo_state",
            "repository_path": helper_json["repository_path"],
            "head": helper_json["head"],
            "branch": helper_json["branch"],
            "clean": helper_json["clean"],
            "status_entries": helper_json["status_entries"],
            "state_kind": repo_obj.attributes["state_kind"],
        }
        diff_state = {
            "document_type": "diff_state",
            "repository_path": helper_json["repository_path"],
            "comparison_ref": helper_json["comparison_ref"],
            "comparison_base": helper_json["comparison_base"],
            "head": helper_json["head"],
            "changed_files": helper_json["changed_files"],
            "file_count": helper_json["file_count"],
            "numstat": helper_json["numstat"],
            "state_kind": diff_obj.attributes["state_kind"],
        }

        repo_path = output_root / "repo_state.json"
        diff_path = output_root / "diff_state.json"
        write_json(repo_path, repo_state)
        write_json(diff_path, diff_state)

        manifest_data = {
            "document_type": "realization_manifest",
            "status": "runtime_surfaces_emitted",
            "runtime_status": "ok",
            "runtime_kind": "gix",
            "build_backend": "cargo",
            "crate_surface": "gix",
            "emitted": [
                {"surface_id": "gix_repo_state", "repo_path": "repo_state.json", "output_path": str(repo_path)},
                {"surface_id": "gix_diff_state", "repo_path": "diff_state.json", "output_path": str(diff_path)},
            ],
        }
        report_data = {
            "document_type": "realization_report",
            "status": "runtime_surfaces_emitted",
            "runtime_status": "ok",
            "runtime_kind": "gix",
            "build_backend": "cargo",
            "crate_surface": "gix",
            "checks": {
                "repo_state": {"status": "ok", "clean": repo_state["clean"], "head": repo_state["head"]},
                "diff_state": {
                    "status": "ok",
                    "comparison_ref": diff_state["comparison_ref"],
                    "comparison_base": diff_state["comparison_base"],
                    "file_count": diff_state["file_count"],
                },
            },
        }
        manifest_path = output_root / "realization_manifest.gix_runtime.json"
        report_path = output_root / "realization_report.gix_runtime.json"
        write_json(manifest_path, manifest_data)
        write_json(report_path, report_data)
        print(json.dumps({"status": "success", "manifest": str(manifest_path), "report": str(report_path)}, indent=2))
        return 0
    except GitProjectionError as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
