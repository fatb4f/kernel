#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from git_projection_common import (
    GitProjectionError,
    emit_diff_state,
    emit_semantic_diff,
    load_json,
    normalize_objects,
    write_json,
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-sem-minimal",
        description="Emit semantic_diff from the Git substrate example using deterministic diff inputs.",
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
        diff_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "diff_state_surface")
        semantic_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "semantic_diff_surface")
        review_obj = next(obj for obj in objects.values() if obj.attributes.get("git_substrate_role") == "review_basis_surface")

        if args.check_only:
            print(
                json.dumps(
                    {
                        "status": "ok",
                        "emittable_files": ["semantic_diff.json"],
                        "object_refs": [semantic_obj.ref, review_obj.ref],
                        "upstream_diff_ref": semantic_obj.attributes["upstream_diff_ref"],
                    },
                    indent=2,
                )
            )
            return 0

        diff_state = emit_diff_state(diff_obj)
        semantic_diff = emit_semantic_diff(semantic_obj, review_obj, diff_state)
        semantic_path = output_root / "semantic_diff.json"
        write_json(semantic_path, semantic_diff)

        manifest = {
            "document_type": "realization_manifest",
            "status": "source_surfaces_emitted",
            "emitted": [
                {"surface_id": "sem_semantic_diff", "repo_path": "semantic_diff.json", "output_path": str(semantic_path)}
            ],
        }
        report = {
            "document_type": "realization_report",
            "status": "source_surfaces_emitted",
            "checks": {
                "semantic_diff": {
                    "status": "ok",
                    "upstream_diff_ref": semantic_diff["upstream_diff_ref"],
                    "file_count": semantic_diff["change_summary"]["file_count"],
                }
            },
        }
        manifest_path = output_root / "realization_manifest.sem_minimal.json"
        report_path = output_root / "realization_report.sem_minimal.json"
        write_json(manifest_path, manifest)
        write_json(report_path, report)
        print(json.dumps({"status": "success", "manifest": str(manifest_path), "report": str(report_path)}, indent=2))
        return 0
    except (GitProjectionError, StopIteration) as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
