#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.metadata
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTROL_ID = "reviewed-structural-draft-surface"
SCHEMA_PATH = REPO_ROOT / "schemas" / "exported" / "reviewed-structural-draft.schema.json"
POLICY_BUNDLE = REPO_ROOT / "policy" / "admission" / "reviewed-structural-draft.cue"
DEFAULT_DRAFT = REPO_ROOT / "examples" / "valid" / "reviewed-structural-draft.example.json"


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def load_json(path: Path) -> dict:
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


def validate_input(draft_path: Path) -> dict:
    schema = load_json(SCHEMA_PATH)
    instance = load_json(draft_path)
    Draft202012Validator(schema).validate(instance)
    return instance


def cue_version() -> str:
    out = subprocess.run(["cue", "version"], check=True, text=True, capture_output=True).stdout.splitlines()
    return out[0] if out else "cue version (unknown)"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize and admit a reviewed structural draft.")
    parser.add_argument("draft", nargs="?", type=Path, default=DEFAULT_DRAFT)
    parser.add_argument("--run-id", default="", help="Optional explicit run identifier")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    run_id = args.run_id or utc_run_id()
    draft_path = args.draft.resolve()
    draft = validate_input(draft_path)

    for phase in ["source-validation", "normalization", "admission"]:
        phase_dir(phase, run_id).mkdir(parents=True, exist_ok=True)

    source_validation_path = phase_dir("source-validation", run_id) / "source-validation.json"
    normalization_dir = phase_dir("normalization", run_id)
    admission_dir = phase_dir("admission", run_id)

    dump_json(
        source_validation_path,
        {
            "gate": "G1",
            "control_object_id": CONTROL_ID,
            "run_id": run_id,
            "status": "PASS",
            "source_ref": rel(draft_path),
            "schema_ref": rel(SCHEMA_PATH),
            "validated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tool": "python-jsonschema",
            "reason_codes": [],
        },
    )

    normalized_state = copy.deepcopy(draft)
    normalized_state["normalization"] = {
        "normalized_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_ref": rel(draft_path),
        "policy_ref": "policy/kernel/prose-contract-workflow.index.json",
        "classification": {
            "contract_surface": "reviewed_structural_draft",
            "next_surface": "json_structure_contract"
        }
    }
    normalized_state_path = normalization_dir / "normalized-state.json"
    dump_json(normalized_state_path, normalized_state)
    dump_json(
        normalization_dir / "source-map.json",
        {
            "source_ref": rel(draft_path),
            "normalized_state_ref": rel(normalized_state_path),
            "mapping": "identity_with_classification",
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
            "notes": [
                "reviewed structural draft remains pre-contract and non-authoritative",
                "normalization classifies the next promotion surface as json_structure_contract",
            ],
        },
    )

    subprocess.run(
        ["cue", "vet", str(POLICY_BUNDLE), str(normalized_state_path), "-d", "#Normalized"],
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
                "reviewed_structural_draft_schema": {
                    "ref": rel(SCHEMA_PATH),
                    "algorithm": "sha256",
                    "value": sha256_path(SCHEMA_PATH),
                },
            },
            "tool_versions": {
                "cue": cue_version(),
                "python_jsonschema": importlib.metadata.version("jsonschema"),
            },
            "issued_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
    )

    print(
        json.dumps(
            {
                "run_id": run_id,
                "draft_ref": rel(draft_path),
                "normalized_state_ref": rel(normalized_state_path),
                "admitted_state_ref": rel(admitted_state_path),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
