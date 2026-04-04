#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from git_projection_common import GitObject, GitProjectionError, load_json, normalize_objects, parse_repository_ref, require_keys


ALLOWED_FAMILIES = {"git_implementation", "git_hydration"}
ALLOWED_BACKENDS = {"gix": "git_implementation", "sem": "git_implementation", "marimo": "git_hydration"}
ALLOWED_ARTIFACT_KINDS = {"state_projection", "enrichment_projection", "hydration_projection"}
PRIMARY_OPERATOR_SURFACE = "control_realize_git_substrate_adapters_v1.py"
RealizationError = GitProjectionError


def resolve_artifact_ref(cwd: Path, ref: str) -> Path:
    if not ref.startswith("artifact:"):
        raise RealizationError(f"unsupported authority ref: {ref}")
    return cwd / ref.removeprefix("artifact:")


def validate_unified_document(document: dict[str, Any], schema: dict[str, Any], ctx: str) -> None:
    require_keys(document, list(schema.get("required", [])), ctx)
    properties = schema.get("properties", {})
    additional_allowed = schema.get("additionalProperties", True)
    if additional_allowed is False:
        extra = sorted(set(document) - set(properties))
        if extra:
            raise RealizationError(f"{ctx} has unexpected keys: {', '.join(extra)}")
    for key, prop in properties.items():
        if key not in document:
            continue
        value = document[key]
        if "const" in prop and value != prop["const"]:
            raise RealizationError(f"{ctx}.{key} must equal {prop['const']!r}")
        prop_type = prop.get("type")
        if prop_type == "string" and not isinstance(value, str):
            raise RealizationError(f"{ctx}.{key} must be a string")
        if prop_type == "boolean" and not isinstance(value, bool):
            raise RealizationError(f"{ctx}.{key} must be a boolean")
        if prop_type == "integer" and not isinstance(value, int):
            raise RealizationError(f"{ctx}.{key} must be an integer")
        if prop_type == "array":
            if not isinstance(value, list):
                raise RealizationError(f"{ctx}.{key} must be an array")
            item_schema = prop.get("items", {})
            if item_schema.get("type") == "object":
                for idx, item in enumerate(value):
                    if not isinstance(item, dict):
                        raise RealizationError(f"{ctx}.{key}[{idx}] must be an object")
                    validate_unified_document(item, item_schema, f"{ctx}.{key}[{idx}]")
            elif item_schema.get("type") == "string":
                for idx, item in enumerate(value):
                    if not isinstance(item, str):
                        raise RealizationError(f"{ctx}.{key}[{idx}] must be a string")
        if prop_type == "object" and isinstance(value, dict):
            nested_required = prop.get("required", [])
            for nested_key in nested_required:
                if nested_key not in value:
                    raise RealizationError(f"{ctx}.{key} missing required key: {nested_key}")


def build_manifest(root: Path, payload: dict[str, Any], emitted: list[dict[str, Any]], cwd: Path) -> Path:
    manifest = {
        "document_type": "realization_manifest",
        "schema_version": "v2",
        "workflow_command": payload["workflow"]["command"],
        "deterministic": payload["workflow"]["deterministic"],
        "primary_operator_surface": PRIMARY_OPERATOR_SURFACE,
        "targets": emitted,
    }
    schema = load_json(cwd.parent / "cli_extension_v2" / "unified_realization_manifest.v2.schema.json")
    validate_unified_document(manifest, schema, "realization_manifest")
    path = root / "build" / "realization_manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def build_report(
    root: Path,
    payload_path: Path,
    emitted: list[dict[str, Any]],
    backend_reports: dict[str, Any],
    cwd: Path,
) -> Path:
    report = {
        "document_type": "realization_report",
        "schema_version": "v2",
        "status": "success",
        "payload_path": str(payload_path),
        "primary_operator_surface": PRIMARY_OPERATOR_SURFACE,
        "realized_count": len(emitted),
        "targets": emitted,
        "backend_reports": backend_reports,
    }
    schema = load_json(cwd.parent / "cli_extension_v2" / "unified_realization_report.v2.schema.json")
    validate_unified_document(report, schema, "realization_report")
    path = root / "build" / "realization_report.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return path


def run_child(cwd: Path, script_name: str, output_root: Path) -> dict[str, Any]:
    result = subprocess.run(
        [sys.executable, str(cwd / script_name), "--output-root", str(output_root)],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RealizationError(f"{script_name} failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def run_check(cwd: Path, script_name: str) -> tuple[dict[str, Any], bool]:
    result = subprocess.run(
        [sys.executable, str(cwd / script_name), "--check-only"],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    payload_text = result.stdout if result.stdout.strip() else result.stderr
    data = json.loads(payload_text)
    return data, result.returncode == 0


def validate_payload(cwd: Path, payload: dict[str, Any]) -> tuple[dict[str, GitObject], dict[str, Any]]:
    require_keys(payload, ["authority_inputs", "realization_scope", "targets", "workflow"], "payload")
    authority = payload["authority_inputs"]
    require_keys(authority, ["canonical_model_ref", "profile_ref", "projection_manifest_ref"], "authority_inputs")
    for key, ref in authority.items():
        path = resolve_artifact_ref(cwd, ref)
        if not path.exists():
            raise RealizationError(f"{key} does not resolve locally: {ref}")

    model = load_json(resolve_artifact_ref(cwd, authority["canonical_model_ref"]))
    objects = normalize_objects(model)
    object_refs = set(objects)

    scope = payload["realization_scope"]
    require_keys(scope, ["allowed_adapter_families", "allowed_backends"], "realization_scope")
    allowed_families = set(scope["allowed_adapter_families"])
    allowed_backends = set(scope["allowed_backends"])
    if allowed_families - ALLOWED_FAMILIES:
        raise RealizationError(f"unknown adapter families: {sorted(allowed_families - ALLOWED_FAMILIES)}")
    if allowed_backends - set(ALLOWED_BACKENDS):
        raise RealizationError(f"unknown backends: {sorted(allowed_backends - set(ALLOWED_BACKENDS))}")

    seen_ids: set[str] = set()
    for target in payload["targets"]:
        require_keys(
            target,
            ["target_id", "backend", "adapter_family", "projection_role", "inputs", "artifact_kind", "repo_path"],
            "target",
        )
        target_id = str(target["target_id"])
        if target_id in seen_ids:
            raise RealizationError(f"duplicate target_id: {target_id}")
        seen_ids.add(target_id)
        backend = str(target["backend"])
        family = str(target["adapter_family"])
        if backend not in allowed_backends:
            raise RealizationError(f"target {target_id}: backend '{backend}' not enabled")
        if family not in allowed_families:
            raise RealizationError(f"target {target_id}: adapter_family '{family}' not enabled")
        if ALLOWED_BACKENDS[backend] != family:
            raise RealizationError(f"target {target_id}: backend '{backend}' does not match adapter_family '{family}'")
        artifact_kind = str(target["artifact_kind"])
        if artifact_kind not in ALLOWED_ARTIFACT_KINDS:
            raise RealizationError(f"target {target_id}: unsupported artifact_kind '{artifact_kind}'")
        inputs = [str(x) for x in target["inputs"]]
        if not inputs:
            raise RealizationError(f"target {target_id}: inputs must not be empty")
        missing = sorted(set(inputs) - object_refs)
        if missing:
            raise RealizationError(f"target {target_id}: unresolved semantic inputs: {', '.join(missing)}")
        if backend == "sem":
            semantic_objects = [objects[ref] for ref in inputs]
            semantic_surface = next(
                (obj for obj in semantic_objects if obj.attributes.get("git_substrate_role") == "semantic_diff_surface"),
                None,
            )
            if semantic_surface is None:
                raise RealizationError(f"target {target_id}: sem target missing semantic_diff_surface input")
            upstream_diff_ref = str(semantic_surface.attributes.get("upstream_diff_ref", ""))
            if upstream_diff_ref not in object_refs:
                raise RealizationError(
                    f"target {target_id}: semantic_diff_surface upstream_diff_ref does not resolve: {upstream_diff_ref}"
                )

    workflow = payload["workflow"]
    require_keys(workflow, ["command", "deterministic", "overwrite_policy", "manifest_update"], "workflow")
    if workflow["command"] != "control realize git-substrate-adapters-v1":
        raise RealizationError("workflow.command must be exactly 'control realize git-substrate-adapters-v1'")
    if workflow["deterministic"] is not True:
        raise RealizationError("workflow.deterministic must be true")

    return objects, payload


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="control realize git-substrate-adapters-v1",
        description="Unified realization runner for the first Git-substrate adapter slice.",
    )
    parser.add_argument("--payload", default="realization_payload.v1.json")
    parser.add_argument("--root", default=".")
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    cwd = Path(__file__).resolve().parent
    payload_path = (cwd / args.payload).resolve() if not Path(args.payload).is_absolute() else Path(args.payload)
    root = Path(args.root).resolve()

    try:
        payload = load_json(payload_path)
        objects, payload = validate_payload(cwd, payload)
        if args.check_only:
            print(json.dumps({"status": "ok", "validated_targets": len(payload["targets"])}, indent=2))
            return 0

        emitted: list[dict[str, Any]] = []
        backend_reports: dict[str, Any] = {"gix": {"targets": []}, "sem": {"targets": []}}
        gix_root = root / "build" / "git" / "codex_home"
        sem_root = root / "build" / "git" / "codex_home"
        gix_runtime_check, gix_runtime_ok = run_check(cwd, "emit_gix_runtime.py")
        sem_runtime_check, sem_runtime_ok = run_check(cwd, "emit_sem_runtime.py")

        if gix_runtime_ok:
            gix_run = run_child(cwd, "emit_gix_runtime.py", gix_root)
            gix_report = load_json(Path(gix_run["report"]))
            gix_runtime_status = "ok"
            gix_mode = "real_runtime"
        else:
            gix_run = run_child(cwd, "emit_gix_minimal.py", gix_root)
            gix_report = load_json(Path(gix_run["report"]))
            gix_runtime_status = "runtime_unavailable_fallback_minimal"
            gix_mode = "minimal_fallback"

        if sem_runtime_ok:
            sem_run = run_child(cwd, "emit_sem_runtime.py", sem_root)
            sem_report = load_json(Path(sem_run["report"]))
            sem_runtime_status = "ok"
            sem_mode = "real_runtime"
        else:
            sem_run = run_child(cwd, "emit_sem_minimal.py", sem_root)
            sem_report = load_json(Path(sem_run["report"]))
            sem_runtime_status = "runtime_unavailable_fallback_minimal"
            sem_mode = "minimal_fallback"

        for target in payload["targets"]:
            backend = str(target["backend"])
            target_id = str(target["target_id"])
            output_path = root / str(target["repo_path"])
            input_objects = [objects[str(ref)] for ref in target["inputs"]]

            if backend == "gix":
                surface = input_objects[0]
                role = str(surface.attributes.get("git_substrate_role"))
                source_name = "repo_state.json" if role == "repo_state_surface" else "diff_state.json"
                source_path = gix_root / source_name
                if not source_path.exists():
                    raise RealizationError(f"target {target_id}: expected gix output missing: {source_path}")
                output_path.parent.mkdir(parents=True, exist_ok=True)
                output_path.write_text(source_path.read_text(encoding="utf-8"), encoding="utf-8")
                if role in {"repo_state_surface", "diff_state_surface"}:
                    backend_reports["gix"]["targets"].append(
                        {
                            "target_id": target_id,
                            "status": "ok",
                            "kind": role,
                            "runtime_status": gix_runtime_status,
                            "runtime_mode": gix_mode,
                        }
                    )
                else:
                    raise RealizationError(f"target {target_id}: unsupported gix role {role!r}")
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": str(target["artifact_kind"]),
                        "repo_path": str(target["repo_path"]),
                        "output_path": str(output_path),
                        "source_project_root": str(parse_repository_ref(str(surface.attributes["repository_ref"]))),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )
            elif backend == "sem":
                semantic_obj = next(obj for obj in input_objects if obj.attributes.get("git_substrate_role") == "semantic_diff_surface")
                source_path = sem_root / "semantic_diff.json"
                if not source_path.exists():
                    raise RealizationError(f"target {target_id}: expected sem output missing: {source_path}")
                output_path.parent.mkdir(parents=True, exist_ok=True)
                output_path.write_text(source_path.read_text(encoding="utf-8"), encoding="utf-8")
                backend_reports["sem"]["targets"].append(
                    {
                        "target_id": target_id,
                        "status": "ok",
                        "kind": "semantic_diff_surface",
                        "runtime_status": sem_runtime_status,
                        "runtime_mode": sem_mode,
                    }
                )
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": str(target["artifact_kind"]),
                        "repo_path": str(target["repo_path"]),
                        "output_path": str(output_path),
                        "source_project_root": str(parse_repository_ref(str(semantic_obj.attributes["repository_ref"]))),
                        "upstream_deterministic_input": str(semantic_obj.attributes["upstream_diff_ref"]),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )

        review_basis_path = sem_root / "review_basis.json"
        if review_basis_path.exists():
            backend_reports["sem"]["review_basis_output"] = str(review_basis_path)
        backend_reports["gix"]["emitter_report"] = gix_report
        backend_reports["gix"]["runtime_check"] = gix_runtime_check
        backend_reports["sem"]["emitter_report"] = sem_report
        backend_reports["sem"]["runtime_check"] = sem_runtime_check

        manifest_path = build_manifest(root, payload, emitted, cwd)
        report_path = build_report(root, payload_path, emitted, backend_reports, cwd)
        print(
            json.dumps(
                {
                    "status": "success",
                    "realized_targets": len(emitted),
                    "manifest": str(manifest_path),
                    "report": str(report_path),
                },
                indent=2,
            )
        )
        return 0
    except RealizationError as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
