#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from git_projection_common import (
    GitProjectionError,
    build_review_basis,
    emit_diff_state,
    load_json,
    normalize_objects,
    parse_repository_ref,
    parse_sem_output,
    resolve_sem_binary,
    write_json,
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-sem-runtime",
        description="Emit semantic_diff and review_basis using the real sem backend when available.",
    )
    parser.add_argument("--model", default="canonical_semantic_model.git.example.json")
    parser.add_argument("--output-root", default="realized/git_substrate/codex_home")
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    base = Path(__file__).resolve().parent
    model_path = (base / args.model).resolve() if not Path(args.model).is_absolute() else Path(args.model)
    output_root = (base / args.output_root).resolve() if not Path(args.output_root).is_absolute() else Path(args.output_root)
    try:
        sem_bin, resolution = resolve_sem_binary()
        if args.check_only:
            print(
                json.dumps(
                    {
                        "status": "ok" if sem_bin else "runtime_unavailable",
                        "runtime_kind": "sem",
                        "runtime_resolution": resolution,
                        "binary": sem_bin,
                    },
                    indent=2,
                )
            )
            return 0 if sem_bin else 2
        if sem_bin is None:
            raise GitProjectionError("sem runtime unavailable")

        model = load_json(model_path)
        objects = normalize_objects(model)
        repo_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "repo_state_surface")
        diff_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "diff_state_surface")
        semantic_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "semantic_diff_surface")
        review_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "review_basis_surface")

        repo = parse_repository_ref(str(diff_obj.attributes["repository_ref"]))
        comparison_ref = str(diff_obj.attributes["comparison_ref"])
        cmd = [sem_bin, "diff", "--from", comparison_ref, "--to", "HEAD", "--format", "json"]
        result = subprocess.run(cmd, cwd=repo, text=True, capture_output=True, check=False)
        if result.returncode != 0:
            raise GitProjectionError(f"sem runtime failed: {result.stderr.strip() or result.stdout.strip()}")
        sem_json = parse_sem_output(result.stdout)
        diff_state = emit_diff_state(diff_obj)
        diff_state["source_ref"] = diff_obj.ref
        review_basis = build_review_basis(review_obj, repo_obj, diff_state)
        semantic_diff = {
            "document_type": "semantic_diff",
            "repository_path": str(repo),
            "repository_ref": semantic_obj.attributes["repository_ref"],
            "upstream_diff_ref": semantic_obj.attributes["upstream_diff_ref"],
            "review_basis_rule": review_obj.attributes["basis_rule"],
            "backend": "sem",
            "runtime_mode": "real",
            "summary": sem_json["summary"],
            "changes": sem_json["changes"],
            "change_summary": {
                "file_count": sem_json["summary"]["fileCount"],
                "total": sem_json["summary"]["total"],
                "added": sem_json["summary"]["added"],
                "modified": sem_json["summary"]["modified"],
                "deleted": sem_json["summary"]["deleted"],
                "moved": sem_json["summary"]["moved"],
                "renamed": sem_json["summary"]["renamed"],
            },
            "review_basis": review_basis,
        }

        semantic_path = output_root / "semantic_diff.json"
        review_basis_path = output_root / "review_basis.json"
        write_json(semantic_path, semantic_diff)
        write_json(review_basis_path, review_basis)

        manifest = {
            "document_type": "realization_manifest",
            "status": "runtime_surfaces_emitted",
            "runtime_status": "ok",
            "runtime_kind": "sem",
            "runtime_resolution": resolution,
            "emitted": [
                {"surface_id": "sem_semantic_diff", "repo_path": "semantic_diff.json", "output_path": str(semantic_path)},
                {"surface_id": "sem_review_basis", "repo_path": "review_basis.json", "output_path": str(review_basis_path)},
            ],
        }
        report = {
            "document_type": "realization_report",
            "status": "runtime_surfaces_emitted",
            "runtime_status": "ok",
            "runtime_kind": "sem",
            "runtime_resolution": resolution,
            "checks": {
                "semantic_diff": {
                    "status": "ok",
                    "upstream_diff_ref": semantic_diff["upstream_diff_ref"],
                    "file_count": semantic_diff["change_summary"]["file_count"],
                    "total_changes": semantic_diff["change_summary"]["total"],
                },
                "review_basis": {
                    "status": "ok",
                    "repo_state_ref": review_basis["repo_state_ref"],
                    "diff_state_ref": review_basis["diff_state_ref"],
                },
            },
        }
        manifest_path = output_root / "realization_manifest.sem_runtime.json"
        report_path = output_root / "realization_report.sem_runtime.json"
        write_json(manifest_path, manifest)
        write_json(report_path, report)
        print(json.dumps({"status": "success", "manifest": str(manifest_path), "report": str(report_path)}, indent=2))
        return 0
    except (GitProjectionError, StopIteration) as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
