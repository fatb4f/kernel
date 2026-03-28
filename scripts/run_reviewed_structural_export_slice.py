#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROL_ID = "reviewed-structural-export-slice"
SOURCE_CONTROL_ID = "reviewed-structural-draft-surface"
SOURCE_ROOT = REPO_ROOT / "generated" / "state" / "admission" / SOURCE_CONTROL_ID
SLICE_SCHEMA_PATH = REPO_ROOT / "schemas" / "exported" / "reviewed-structural-export-slice-input.schema.json"
WORKFLOW_POLICY_PATH = REPO_ROOT / "policy" / "kernel" / "prose-contract-workflow.index.json"
RENDER_TEMPLATE = REPO_ROOT / "render" / "jsonnet" / "registry" / "reviewed-structural-export.jsonnet"
RENDERED_REGISTRY = REPO_ROOT / "generated" / "registries" / "reviewed-structural-export.index.json"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def load_json(path: Path) -> object:
    return json.loads(path.read_text())


def dump_json(path: Path, instance: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(instance, indent=2) + "\n")


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def phase_dir(phase: str, run_id: str) -> Path:
    return REPO_ROOT / "generated" / "state" / phase / CONTROL_ID / run_id


def latest_admitted_state() -> Path:
    candidates = sorted(
        path / "admitted-state.json"
        for path in SOURCE_ROOT.iterdir()
        if path.is_dir() and (path / "admitted-state.json").exists()
    )
    if not candidates:
        raise FileNotFoundError("no admitted reviewed-structural-draft state found")
    return candidates[-1]


def jsonnet_bin() -> str:
    if shutil_which := subprocess.run(
        ["bash", "-lc", "command -v rsjsonnet || true"], text=True, capture_output=True, check=True
    ).stdout.strip():
        return shutil_which
    cargo_bin = Path.home() / ".local" / "share" / "cargo" / "bin" / "rsjsonnet"
    if cargo_bin.exists():
        return str(cargo_bin)
    raise FileNotFoundError("rsjsonnet not found")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export schema and constraint sidecars from admitted reviewed drafts.")
    parser.add_argument("admitted_state", nargs="?", type=Path, help="Optional admitted-state.json path")
    parser.add_argument("--run-id", default="", help="Optional explicit run identifier")
    return parser.parse_args()


def validate_source(instance: dict) -> None:
    if instance.get("artifact_type") != "kernel.reviewed_structural_draft":
        raise ValueError("admitted state is not a reviewed structural draft")
    if instance.get("admission", {}).get("decision") != "ALLOW":
        raise ValueError("admitted state is not ALLOW")
    if not instance.get("structures"):
        raise ValueError("admitted state has no structures")


def json_type(field: dict) -> dict:
    field_type = field["type"]
    mapping = {
        "string": {"type": "string"},
        "integer": {"type": "integer"},
        "number": {"type": "number"},
        "boolean": {"type": "boolean"},
    }
    if field_type == "array":
        items_type = field.get("items_type", "string")
        item_schema = mapping.get(items_type, {"type": items_type})
        return {"type": "array", "items": item_schema}
    return mapping.get(field_type, {"type": field_type})


def build_schema_base(admitted_state: dict, schema_ref: str) -> dict:
    structures = admitted_state["structures"]
    defs: dict[str, dict] = {}
    for structure in structures:
        properties: dict[str, dict] = {}
        required: list[str] = []
        for field in structure["fields"]:
            field_schema = json_type(field)
            if "description" in field:
                field_schema["description"] = field["description"]
            properties[field["name"]] = field_schema
            if field.get("required"):
                required.append(field["name"])
        defs[structure["name"]] = {
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        }

    root_name = structures[0]["name"]
    root_def = defs[root_name]
    schema_base = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": schema_ref,
        "title": admitted_state["title"],
        "type": "object",
        "properties": root_def["properties"],
        "required": root_def["required"],
        "additionalProperties": False,
        "$defs": defs,
        "x-derived-from": {
            "artifact_type": admitted_state["artifact_type"],
            "draft_id": admitted_state["draft_id"],
            "source_policy_ref": admitted_state.get("source_policy_ref", rel(WORKFLOW_POLICY_PATH)),
        },
    }
    return schema_base


def build_constraint_sidecars(admitted_state: dict, manifest_ref: str, preservation_ref: str) -> tuple[dict, dict]:
    constraints = admitted_state.get("constraints", [])
    manifest_entries = []
    report_entries = []
    externalized = 0
    embedded = 0
    for constraint in constraints:
        preservation_mode = "externalized"
        structural_status = "not_embedded"
        reason = "requires_constraint_sidecar_to_preserve_semantics"
        manifest_entries.append(
            {
                "id": constraint["id"],
                "subject": constraint["subject"],
                "constraint_class": constraint["constraint_class"],
                "predicate": constraint.get("predicate"),
                "loss_policy": constraint["loss_policy"],
                "notes": constraint.get("notes"),
                "preservation_mode": preservation_mode,
                "structural_schema_status": structural_status,
            }
        )
        report_entries.append(
            {
                "constraint_id": constraint["id"],
                "preservation_mode": preservation_mode,
                "structural_schema_status": structural_status,
                "reason": reason,
                "constraint_manifest_ref": manifest_ref,
            }
        )
        externalized += 1

    constraints_manifest = {
        "artifact_type": "kernel.constraint_manifest",
        "artifact_version": "0.1.0",
        "source_admitted_state_ref": "",
        "constraints": manifest_entries,
        "notes": [
            "constraints.manifest.json preserves admitted constraint semantics not embedded in schema.base.json"
        ],
    }
    preservation_report = {
        "artifact_type": "kernel.constraint_preservation_report",
        "artifact_version": "0.1.0",
        "source_admitted_state_ref": "",
        "summary": {
            "total_constraints": len(constraints),
            "embedded_in_schema_base": embedded,
            "externalized_to_manifest": externalized,
            "dropped": 0,
        },
        "entries": report_entries,
        "notes": [
            "No admitted constraint may be silently weakened or dropped.",
            f"Preservation details are recorded in {preservation_ref}.",
        ],
    }
    return constraints_manifest, preservation_report


def build_export_slice_input(
    admitted_state_ref: str,
    schema_base_ref: str,
    constraints_manifest_ref: str,
    preservation_report_ref: str,
    admitted_state: dict,
    constraints_manifest: dict,
) -> dict:
    return {
        "kind": "kernel.reviewed_structural_export.slice_input",
        "control_object_id": CONTROL_ID,
        "source_surface_control_id": SOURCE_CONTROL_ID,
        "source_admitted_state_ref": admitted_state_ref,
        "source_policy_ref": admitted_state.get("source_policy_ref", rel(WORKFLOW_POLICY_PATH)),
        "output_bundle": {
            "schema_base_ref": schema_base_ref,
            "constraints_manifest_ref": constraints_manifest_ref,
            "constraint_preservation_report_ref": preservation_report_ref,
        },
        "structures": [
            {
                "name": structure["name"],
                "kind": structure["kind"],
                "field_count": len(structure["fields"]),
                "is_root": index == 0,
            }
            for index, structure in enumerate(admitted_state["structures"])
        ],
        "constraints": [
            {
                "id": constraint["id"],
                "constraint_class": constraint["constraint_class"],
                "preservation_mode": constraint["preservation_mode"],
                "structural_schema_status": constraint["structural_schema_status"],
            }
            for constraint in constraints_manifest["constraints"]
        ],
        "render_contract": {
            "renderer": "jsonnet",
            "runtime": "rsjsonnet",
            "input_class": "admitted_state",
            "output_class": "registry",
        },
    }


def main() -> int:
    args = parse_args()
    run_id = args.run_id or utc_run_id()
    admitted_state_path = args.admitted_state.resolve() if args.admitted_state else latest_admitted_state()
    admitted_state = load_json(admitted_state_path)
    validate_source(admitted_state)

    for phase in ["source-validation", "export", "render", "integrity"]:
        phase_dir(phase, run_id).mkdir(parents=True, exist_ok=True)
    REPO_ROOT.joinpath("generated", "registries").mkdir(parents=True, exist_ok=True)

    source_validation_path = phase_dir("source-validation", run_id) / "source-validation.json"
    export_dir = phase_dir("export", run_id)
    render_dir = phase_dir("render", run_id)
    integrity_dir = phase_dir("integrity", run_id)

    admitted_state_ref = rel(admitted_state_path)
    schema_base_path = export_dir / "schema.base.json"
    constraints_manifest_path = export_dir / "constraints.manifest.json"
    preservation_report_path = export_dir / "constraint-preservation.report.json"
    export_slice_input_path = export_dir / "export-slice-input.json"

    dump_json(
        source_validation_path,
        {
            "gate": "G1",
            "control_object_id": CONTROL_ID,
            "source_control_object_id": SOURCE_CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "validated_at": utc_now(),
            "source_admitted_state_ref": admitted_state_ref,
            "slice_schema_ref": rel(SLICE_SCHEMA_PATH),
            "reason_codes": [],
            "tool": "python-jsonschema",
        },
    )

    schema_base = build_schema_base(admitted_state, rel(schema_base_path))
    dump_json(schema_base_path, schema_base)
    constraints_manifest, preservation_report = build_constraint_sidecars(
        admitted_state, rel(constraints_manifest_path), rel(preservation_report_path)
    )
    constraints_manifest["source_admitted_state_ref"] = admitted_state_ref
    preservation_report["source_admitted_state_ref"] = admitted_state_ref
    dump_json(constraints_manifest_path, constraints_manifest)
    dump_json(preservation_report_path, preservation_report)

    export_slice_input = build_export_slice_input(
        admitted_state_ref,
        rel(schema_base_path),
        rel(constraints_manifest_path),
        rel(preservation_report_path),
        admitted_state,
        constraints_manifest,
    )
    Draft202012Validator(load_json(SLICE_SCHEMA_PATH)).validate(export_slice_input)
    dump_json(export_slice_input_path, export_slice_input)

    dump_json(
        export_dir / "export-report.json",
        {
            "gate": "G2",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "source_admitted_state_ref": admitted_state_ref,
            "outputs": [
                rel(export_slice_input_path),
                rel(schema_base_path),
                rel(constraints_manifest_path),
                rel(preservation_report_path),
            ],
            "notes": [
                "schema.base.json is a derived structural export only",
                "constraints.manifest.json preserves constraint semantics not embedded in schema.base.json",
                "constraint-preservation.report.json records that no admitted constraint was silently dropped",
            ],
        },
    )

    jsonnet_runtime = jsonnet_bin()
    rendered = subprocess.run(
        [
            jsonnet_runtime,
            "--ext-code-file",
            f"admitted_state={admitted_state_path}",
            "--ext-code-file",
            f"export_slice_input={export_slice_input_path}",
            "--ext-str",
            f"schema_base_ref={rel(schema_base_path)}",
            "--ext-str",
            f"constraints_manifest_ref={rel(constraints_manifest_path)}",
            "--ext-str",
            f"constraint_preservation_report_ref={rel(preservation_report_path)}",
            str(RENDER_TEMPLATE),
        ],
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    RENDERED_REGISTRY.write_text(rendered)

    dump_json(
        render_dir / "render-report.json",
        {
            "gate": "G5",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "renderer": "jsonnet",
            "runtime": "rsjsonnet",
            "runtime_path": jsonnet_runtime,
            "template_ref": rel(RENDER_TEMPLATE),
            "admitted_state_ref": admitted_state_ref,
            "export_slice_input_ref": rel(export_slice_input_path),
            "outputs": [rel(RENDERED_REGISTRY)],
            "rendered_at": utc_now(),
        },
    )

    rerendered = subprocess.run(
        [
            jsonnet_runtime,
            "--ext-code-file",
            f"admitted_state={admitted_state_path}",
            "--ext-code-file",
            f"export_slice_input={export_slice_input_path}",
            "--ext-str",
            f"schema_base_ref={rel(schema_base_path)}",
            "--ext-str",
            f"constraints_manifest_ref={rel(constraints_manifest_path)}",
            "--ext-str",
            f"constraint_preservation_report_ref={rel(preservation_report_path)}",
            str(RENDER_TEMPLATE),
        ],
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    drift_status = "PASS" if rerendered == rendered else "FAIL"
    dump_json(
        integrity_dir / "drift-report.json",
        {
            "gate": "G6",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": drift_status,
            "checked_at": utc_now(),
            "checks": [
                "exported schema and sidecars are present",
                "rendered registry regenerates without drift",
                "export slice input validates against its exported schema",
            ],
            "digests": {
                "schema_base": {
                    "ref": rel(schema_base_path),
                    "algorithm": "sha256",
                    "value": sha256_path(schema_base_path),
                },
                "constraints_manifest": {
                    "ref": rel(constraints_manifest_path),
                    "algorithm": "sha256",
                    "value": sha256_path(constraints_manifest_path),
                },
                "constraint_preservation_report": {
                    "ref": rel(preservation_report_path),
                    "algorithm": "sha256",
                    "value": sha256_path(preservation_report_path),
                },
                "rendered_registry": {
                    "ref": rel(RENDERED_REGISTRY),
                    "algorithm": "sha256",
                    "value": sha256_path(RENDERED_REGISTRY),
                },
            },
            "tool_versions": {
                "python_jsonschema": importlib.metadata.version("jsonschema"),
            },
        },
    )
    if drift_status != "PASS":
        raise SystemExit("render drift detected")

    print(
        json.dumps(
            {
                "run_id": run_id,
                "source_admitted_state_ref": admitted_state_ref,
                "schema_base_ref": rel(schema_base_path),
                "constraints_manifest_ref": rel(constraints_manifest_path),
                "constraint_preservation_report_ref": rel(preservation_report_path),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
