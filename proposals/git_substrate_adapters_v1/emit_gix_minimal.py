#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from git_projection_common import (
    GitProjectionError,
    emit_diff_state,
    emit_repo_state,
    load_json,
    normalize_objects,
    write_json,
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-gix-minimal",
        description="Emit deterministic repo_state and diff_state artifacts from the Git substrate example.",
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
        model = load_json(model_path)
        objects = normalize_objects(model)
        repo_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "repo_state_surface")
        diff_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "diff_state_surface")

        if args.check_only:
            print(
                json.dumps(
                    {
                        "status": "ok",
                        "emittable_files": ["repo_state.json", "diff_state.json"],
                        "object_refs": [repo_obj.ref, diff_obj.ref],
                    },
                    indent=2,
                )
            )
            return 0

        repo_state = emit_repo_state(repo_obj)
        diff_state = emit_diff_state(diff_obj)
        repo_path = output_root / "repo_state.json"
        diff_path = output_root / "diff_state.json"
        write_json(repo_path, repo_state)
        write_json(diff_path, diff_state)

        manifest = {
            "document_type": "realization_manifest",
            "status": "source_surfaces_emitted",
            "emitted": [
                {"surface_id": "gix_repo_state", "repo_path": "repo_state.json", "output_path": str(repo_path)},
                {"surface_id": "gix_diff_state", "repo_path": "diff_state.json", "output_path": str(diff_path)},
            ],
        }
        report = {
            "document_type": "realization_report",
            "status": "source_surfaces_emitted",
            "checks": {
                "repo_state": {"status": "ok", "clean": repo_state["clean"]},
                "diff_state": {"status": "ok", "file_count": diff_state["file_count"]},
            },
        }
        manifest_path = output_root / "realization_manifest.gix_minimal.json"
        report_path = output_root / "realization_report.gix_minimal.json"
        write_json(manifest_path, manifest)
        write_json(report_path, report)
        print(json.dumps({"status": "success", "manifest": str(manifest_path), "report": str(report_path)}, indent=2))
        return 0
    except (GitProjectionError, StopIteration) as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
