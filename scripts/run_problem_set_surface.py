#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROL_ID = "problem-set-surface"
WORKFLOW_ROOT = REPO_ROOT / "generated" / "schemas" / "chatgpt-pipeline" / "workflow"
DEFAULT_PROBLEM_SET = (
    REPO_ROOT / "generated" / "problem_sets" / "ps-kernel-json-family-amendment-001" / "problem_set.json"
)
POLICY_BUNDLE = REPO_ROOT / "policy" / "admission" / "problem-set-surface.cue"
REVIEW_TEMPLATE = REPO_ROOT / "render" / "jsonnet" / "reference" / "problem-set-review.md.jsonnet"
SUMMARY_TEMPLATE = REPO_ROOT / "render" / "jsonnet" / "reference" / "problem-set-summary.jsonnet"


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def dump_json(path: Path, instance: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(instance, indent=2) + "\n")


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def validate_problem_set(problem_set_path: Path) -> dict:
    schema = load_json(WORKFLOW_ROOT / "problem_set.schema.json")
    instance = load_json(problem_set_path)
    Draft202012Validator(schema).validate(instance)
    return instance


def phase_dir(phase: str, run_id: str) -> Path:
    return REPO_ROOT / "generated" / "state" / phase / CONTROL_ID / run_id


def jsonnet_bin() -> str:
    if shutil.which("rsjsonnet"):
        return shutil.which("rsjsonnet")  # type: ignore[return-value]
    fallback = Path.home() / ".local" / "share" / "cargo" / "bin" / "rsjsonnet"
    if fallback.exists():
        return str(fallback)
    raise RuntimeError("rsjsonnet not found")


def cue_version() -> str:
    out = subprocess.run(["cue", "version"], check=True, text=True, capture_output=True).stdout.splitlines()
    return out[0] if out else "cue version (unknown)"


def render_string(template: Path, admitted_state: Path, output: Path) -> str:
    runtime = jsonnet_bin()
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            runtime,
            "--string",
            "--output-file",
            str(output),
            "--ext-code-file",
            f"admitted_state={admitted_state}",
            str(template),
        ],
        check=True,
    )
    return runtime


def render_json(template: Path, admitted_state: Path, output: Path) -> str:
    runtime = jsonnet_bin()
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            runtime,
            "--output-file",
            str(output),
            "--ext-code-file",
            f"admitted_state={admitted_state}",
            str(template),
        ],
        check=True,
    )
    return runtime


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Admit and render a normalized problem_set surface.")
    parser.add_argument("problem_set", nargs="?", type=Path, default=DEFAULT_PROBLEM_SET)
    parser.add_argument("--run-id", default="", help="Optional explicit run identifier")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    run_id = args.run_id or utc_run_id()
    problem_set_path = args.problem_set.resolve()
    problem_set = validate_problem_set(problem_set_path)

    for phase in ["source-validation", "normalization", "admission", "render", "integrity"]:
        phase_dir(phase, run_id).mkdir(parents=True, exist_ok=True)

    source_validation_path = phase_dir("source-validation", run_id) / "source-validation.json"
    normalization_dir = phase_dir("normalization", run_id)
    admission_dir = phase_dir("admission", run_id)
    render_dir = phase_dir("render", run_id)
    integrity_dir = phase_dir("integrity", run_id)

    source_validation = {
        "gate": "G1",
        "control_object_id": CONTROL_ID,
        "run_id": run_id,
        "status": "PASS",
        "source_ref": rel(problem_set_path),
        "schema_ref": "generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json",
        "validated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tool": "python-jsonschema",
        "reason_codes": [],
    }
    dump_json(source_validation_path, source_validation)

    normalized_state = copy.deepcopy(problem_set)
    normalized_state["normalization"] = {
        "normalized_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_ref": rel(problem_set_path),
        "policy": "problem_set is already the normalized ingress object",
    }
    normalized_state_path = normalization_dir / "normalized-state.json"
    dump_json(normalized_state_path, normalized_state)
    dump_json(
        normalization_dir / "source-map.json",
        {
            "source_ref": rel(problem_set_path),
            "normalized_state_ref": rel(normalized_state_path),
            "mapping": "identity",
        },
    )
    dump_json(
        normalization_dir / "normalization-report.json",
        {
            "gate": "G3",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "normalized_state_ref": rel(normalized_state_path),
            "notes": ["problem_set.json is the normalized authority instance for the run"],
        },
    )

    subprocess.run(
        [
            "cue",
            "vet",
            str(POLICY_BUNDLE),
            str(normalized_state_path),
            "-d",
            "#Normalized",
        ],
        check=True,
    )

    admitted_state = copy.deepcopy(normalized_state)
    admitted_state["admission"] = {
        "decision": "ALLOW",
        "policy_bundle_id": rel(POLICY_BUNDLE),
        "admitted_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    admitted_state_path = admission_dir / "admitted-state.json"
    dump_json(admitted_state_path, admitted_state)
    dump_json(admission_dir / "violations.json", [])
    dump_json(
        admission_dir / "decision.json",
        {
            "decision": "ALLOW",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "policy_bundle_id": rel(POLICY_BUNDLE),
            "input_digests": {
                "normalized_state": {
                    "ref": rel(normalized_state_path),
                    "algorithm": "sha256",
                    "value": sha256_path(normalized_state_path),
                },
                "problem_set_schema": {
                    "ref": "generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json",
                    "algorithm": "sha256",
                    "value": sha256_path(WORKFLOW_ROOT / "problem_set.schema.json"),
                },
            },
            "tool_versions": {
                "cue": cue_version(),
            },
            "issued_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
    )

    rendered_doc = REPO_ROOT / "generated" / "docs" / "problem-sets" / f"{problem_set['problem_set_id']}.md"
    rendered_summary = render_dir / "problem-set.summary.json"
    runtime = render_string(REVIEW_TEMPLATE, admitted_state_path, rendered_doc)
    render_json(SUMMARY_TEMPLATE, admitted_state_path, rendered_summary)
    dump_json(
        render_dir / "render-report.json",
        {
            "gate": "G5",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "renderer": "jsonnet",
            "runtime": "rsjsonnet",
            "runtime_path": runtime,
            "templates": [rel(REVIEW_TEMPLATE), rel(SUMMARY_TEMPLATE)],
            "admitted_state_ref": rel(admitted_state_path),
            "outputs": [rel(rendered_doc), rel(rendered_summary)],
            "rendered_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
    )

    dump_json(
        integrity_dir / "drift-report.json",
        {
            "gate": "G6",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "tracked_inputs": [
                {
                    "ref": rel(normalized_state_path),
                    "algorithm": "sha256",
                    "value": sha256_path(normalized_state_path),
                },
                {
                    "ref": rel(admitted_state_path),
                    "algorithm": "sha256",
                    "value": sha256_path(admitted_state_path),
                },
            ],
            "tracked_outputs": [
                {
                    "ref": rel(rendered_doc),
                    "algorithm": "sha256",
                    "value": sha256_path(rendered_doc),
                },
                {
                    "ref": rel(rendered_summary),
                    "algorithm": "sha256",
                    "value": sha256_path(rendered_summary),
                },
            ],
        },
    )

    print(rel(rendered_doc))
    print(rel(rendered_summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
