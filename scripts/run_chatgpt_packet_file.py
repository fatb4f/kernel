#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
PACKET_SCHEMA_ROOT = REPO_ROOT / "generated" / "schemas" / "chatgpt-pipeline" / "packet"
DEFAULT_PACKET_ROOT = REPO_ROOT / "generated" / "packets" / "pkt-kernel-chatgpt-operational-lane-004"
CONTROL_OBJECT_ID = "chatgpt-packet-file-runner"

SCHEMA_MAP = {
    "packet.definition.json": PACKET_SCHEMA_ROOT / "packet.definition.schema.json",
    "scm.pattern.binding.json": PACKET_SCHEMA_ROOT / "scm.pattern.binding.schema.json",
    "packet.review.request.json": PACKET_SCHEMA_ROOT / "packet.review.request.schema.json",
    "root.trust.evidence.json": PACKET_SCHEMA_ROOT / "root.trust.evidence.schema.json",
    "regen.record.json": PACKET_SCHEMA_ROOT / "regen.record.schema.json",
    "artifact.manifest.json": PACKET_SCHEMA_ROOT / "artifact.manifest.schema.json",
    "packet.approval.json": PACKET_SCHEMA_ROOT / "packet.approval.schema.json",
    "packet.review.decision.json": PACKET_SCHEMA_ROOT / "packet.review.decision.schema.json",
}


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def canonical_json_bytes(instance: object) -> bytes:
    return (json.dumps(instance, sort_keys=True, separators=(",", ":")) + "\n").encode()


def ensure_repo_relative(ref: str) -> None:
    ref_path = Path(ref)
    if ref_path.is_absolute() or ".." in ref_path.parts:
        raise ValueError(f"non repo-relative ref: {ref}")


def validate_instance(instance_path: Path, schema_path: Path) -> None:
    schema = load_json(schema_path)
    instance = load_json(instance_path)
    Draft202012Validator(schema).validate(instance)


def resolve_ref(ref: str) -> Path:
    ensure_repo_relative(ref)
    path = REPO_ROOT / ref
    if not path.exists():
        raise FileNotFoundError(ref)
    return path


def packet_root_from_arg(packet_arg: str) -> Path:
    candidate = Path(packet_arg)
    if candidate.name == "packet.definition.json":
        return candidate.resolve().parents[1]
    if candidate.is_absolute():
        return candidate.resolve()
    return (REPO_ROOT / candidate).resolve()


def verify_required_machine_artifacts(packet_root: Path) -> dict[str, Path]:
    machine_root = packet_root / "machine"
    required = {
        "packet.definition.json": machine_root / "packet.definition.json",
        "scm.pattern.binding.json": machine_root / "scm.pattern.binding.json",
        "packet.review.request.json": machine_root / "packet.review.request.json",
        "root.trust.evidence.json": machine_root / "root.trust.evidence.json",
        "regen.record.json": machine_root / "regen.record.json",
        "artifact.manifest.json": machine_root / "artifact.manifest.json",
        "packet.approval.json": machine_root / "packet.approval.json",
    }
    missing = [name for name, path in required.items() if not path.exists()]
    if missing:
        raise FileNotFoundError(f"missing required packet artifacts: {missing}")
    human_definition = packet_root / "human" / "packet.definition.md"
    if not human_definition.exists():
        raise FileNotFoundError("missing human/packet.definition.md")
    required["human/packet.definition.md"] = human_definition
    decision = machine_root / "packet.review.decision.json"
    if decision.exists():
        required["packet.review.decision.json"] = decision
    return required


def validate_packet_family(artifacts: dict[str, Path]) -> dict[str, dict]:
    validations: dict[str, dict] = {}
    for filename, path in artifacts.items():
        if filename == "human/packet.definition.md":
            continue
        schema_path = SCHEMA_MAP[filename]
        validate_instance(path, schema_path)
        validations[filename] = {
            "path": str(path.relative_to(REPO_ROOT)),
            "schema": str(schema_path.relative_to(REPO_ROOT)),
            "status": "PASS",
        }
    return validations


def verify_refs(packet_definition: dict, review_request: dict, binding: dict, manifest: dict) -> dict[str, dict]:
    refs = {
        "packet_inputs": {"required": [item["ref"] for item in packet_definition.get("inputs", [])]},
        "deliverables_now": {"required": [item["ref"] for item in packet_definition["deliverables"]["required_now"]]},
        "deliverables_conditional": {
            "conditional": [item["ref"] for item in packet_definition["deliverables"].get("conditional", [])]
        },
        "review_basis_refs": {"required": review_request.get("review_basis_refs", [])},
        "binding_reads": {"required": binding["realization_scope"].get("read_paths", [])},
        "binding_writes": {"required": binding["realization_scope"].get("write_paths", [])},
        "binding_conditional_writes": {
            "conditional": binding["realization_scope"].get("conditional_write_paths", [])
        },
        "manifest_required": {"required": [item["ref"] for item in manifest.get("required_artifacts", [])]},
        "manifest_conditional": {"conditional": [item["ref"] for item in manifest.get("conditional_artifacts", [])]},
        "trust_requirements": {
            "required": [
                value for key, value in packet_definition.get("kernel_trust_requirements", {}).items() if key.endswith("_ref")
            ]
        },
    }
    for group in refs.values():
        for ref in group.get("required", []):
            resolve_ref(ref)
        for ref in group.get("conditional", []):
            ensure_repo_relative(ref)
    return refs


def verify_human_markdown(packet_definition: dict, human_path: Path) -> None:
    human_text = human_path.read_text()
    if packet_definition["title"] not in human_text:
        raise ValueError("human markdown missing packet title")
    if "## Summary" not in human_text:
        raise ValueError("human markdown missing Summary section")
    key_terms = ["problem_set", "review", "realization"]
    lowered = human_text.lower()
    for term in key_terms:
        if term.lower() not in lowered:
            raise ValueError(f"human markdown missing key summary term: {term}")


def verify_root_trust(evidence: dict) -> dict[str, dict]:
    verified: dict[str, dict] = {}
    for key, declared in evidence["canonical_fingerprints"].items():
        ref_key = f"{key}_ref"
        ref = evidence["canonical_refs"].get(ref_key)
        if ref is None:
            raise ValueError(f"missing canonical ref for fingerprint key: {key}")
        actual_path = resolve_ref(ref)
        actual = sha256_path(actual_path)
        if actual != declared["value"]:
            raise ValueError(f"root trust fingerprint mismatch for {key}")
        verified[key] = {
            "ref": ref,
            "algorithm": declared["algorithm"],
            "value": actual,
        }
    return verified


def verify_regen_record(regen: dict, packet_root: Path) -> dict[str, str]:
    output_fingerprints = regen["output_fingerprints"]
    packet_files = list((packet_root / "machine").glob("*")) + list((packet_root / "human").glob("*"))
    file_by_name = {path.name: path for path in packet_files}
    alias_map = {
        "packet_definition": "packet.definition.json",
        "scm_pattern_binding": "scm.pattern.binding.json",
        "packet_review_request": "packet.review.request.json",
        "root_trust_evidence": "root.trust.evidence.json",
        "artifact_manifest": "artifact.manifest.json",
        "packet_approval": "packet.approval.json",
        "derived_human_definition": "packet.definition.md",
    }
    verified: dict[str, str] = {}
    for name, declared in output_fingerprints.items():
        candidate = file_by_name.get(name) or file_by_name.get(alias_map.get(name, ""))
        if candidate is None:
            raise FileNotFoundError(f"regen output missing from packet root: {name}")
        actual = sha256_path(candidate)
        if actual != declared:
            raise ValueError(f"regen fingerprint mismatch for {name}")
        verified[name] = actual
    return verified


def determine_gate_state(packet_root: Path, packet_approval: dict) -> dict:
    decision_path = packet_root / "machine" / "packet.review.decision.json"
    if packet_approval.get("approval_authority"):
        raise ValueError("packet.approval.json must remain non-authoritative")
    if decision_path.exists():
        decision = load_json(decision_path)
        if not decision.get("approval_authority", False):
            raise ValueError("packet.review.decision.json exists but is non-authoritative")
        return {
            "review_gate": "PASS",
            "realization_gate": "READY_FOR_REALIZATION",
            "next_step": "Local runtime may realize through scm.pattern.",
            "decision_present": True,
        }
    return {
        "review_gate": "PASS",
        "realization_gate": "WAITING_HUMAN_REVIEW",
        "next_step": "Issue authoritative packet.review.decision.json before realization.",
        "decision_present": False,
    }


def write_log_artifacts(
    packet_root: Path,
    run_id: str,
    dry_run: bool,
    packet_definition: dict,
    refs: dict[str, list[str]],
    schema_validations: dict[str, dict],
    trust_verification: dict[str, dict],
    regen_verification: dict[str, str],
    gate_state: dict,
) -> Path:
    log_root = REPO_ROOT / "generated" / "state" / "admission" / CONTROL_OBJECT_ID / run_id
    log_root.mkdir(parents=True, exist_ok=False)

    packet_rel = str(packet_root.relative_to(REPO_ROOT))
    packet_digest = sha256_bytes(canonical_json_bytes(packet_definition))

    execution_log = {
        "artifact_type": "kernel.chatgpt_packet_file_runner_log",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "mode": "DRY_RUN" if dry_run else "EXECUTE",
        "packet_root": packet_rel,
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "steps": [
            {"name": "load packet root", "status": "PASS", "detail": packet_rel},
            {"name": "validate packet schemas", "status": "PASS", "artifacts": schema_validations},
            {"name": "resolve packet refs", "status": "PASS", "ref_groups": refs},
            {"name": "verify root trust fingerprints", "status": "PASS", "fingerprints": trust_verification},
            {"name": "verify regen record", "status": "PASS", "verified_outputs": regen_verification},
            {
                "name": "check review boundary",
                "status": "PASS",
                "review_gate": gate_state["review_gate"],
                "realization_gate": gate_state["realization_gate"],
                "next_step": gate_state["next_step"],
            },
        ],
        "planned_actions": [
            "No realization during dry-run.",
            "No writes outside generated/state admission logs.",
            "Canonical packet artifacts treated as execution contract inputs.",
        ],
    }

    decision = {
        "artifact_type": "kernel.admission.decision",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "decision": "ALLOW",
        "summary": "Packet file contract validated successfully. Dry-run stopped at review boundary.",
        "policy_bundle_id": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json",
        "input_digests": {
            "packet_definition": {
                "algorithm": "sha256",
                "value": packet_digest,
            }
        },
        "tool_versions": {
            "python": sys.version.split()[0],
            "runner": "scripts/run_chatgpt_packet_file.py",
        },
        "result": gate_state,
    }

    violations = {
        "artifact_type": "kernel.admission.violations",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "violations": [],
    }

    admitted_state = {
        "artifact_type": "kernel.admitted_state",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "mode": execution_log["mode"],
        "packet_id": packet_definition["packet_id"],
        "packet_root": packet_rel,
        "admission": "PASS",
        "review_gate": gate_state["review_gate"],
        "realization_gate": gate_state["realization_gate"],
        "next_step": gate_state["next_step"],
    }

    (log_root / "execution-log.json").write_text(json.dumps(execution_log, indent=2) + "\n")
    (log_root / "decision.json").write_text(json.dumps(decision, indent=2) + "\n")
    (log_root / "violations.json").write_text(json.dumps(violations, indent=2) + "\n")
    (log_root / "admitted-state.json").write_text(json.dumps(admitted_state, indent=2) + "\n")
    return log_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Dry-run packet runner for chatgpt-pipeline packet files.")
    parser.add_argument(
        "packet",
        nargs="?",
        default=str(DEFAULT_PACKET_ROOT.relative_to(REPO_ROOT)),
        help="Packet root or machine/packet.definition.json path",
    )
    parser.add_argument("--run-id", default=utc_run_id())
    parser.add_argument("--execute", action="store_true", help="Reserved for future non-dry-run execution.")
    args = parser.parse_args()

    dry_run = not args.execute
    packet_root = packet_root_from_arg(args.packet)
    artifacts = verify_required_machine_artifacts(packet_root)

    schema_validations = validate_packet_family(artifacts)
    packet_definition = load_json(artifacts["packet.definition.json"])
    review_request = load_json(artifacts["packet.review.request.json"])
    binding = load_json(artifacts["scm.pattern.binding.json"])
    trust_evidence = load_json(artifacts["root.trust.evidence.json"])
    regen_record = load_json(artifacts["regen.record.json"])
    artifact_manifest = load_json(artifacts["artifact.manifest.json"])
    packet_approval = load_json(artifacts["packet.approval.json"])

    refs = verify_refs(packet_definition, review_request, binding, artifact_manifest)
    verify_human_markdown(packet_definition, artifacts["human/packet.definition.md"])
    trust_verification = verify_root_trust(trust_evidence)
    regen_verification = verify_regen_record(regen_record, packet_root)
    gate_state = determine_gate_state(packet_root, packet_approval)

    log_root = write_log_artifacts(
        packet_root=packet_root,
        run_id=args.run_id,
        dry_run=dry_run,
        packet_definition=packet_definition,
        refs=refs,
        schema_validations=schema_validations,
        trust_verification=trust_verification,
        regen_verification=regen_verification,
        gate_state=gate_state,
    )

    print(
        json.dumps(
            {
                "run_id": args.run_id,
                "mode": "DRY_RUN" if dry_run else "EXECUTE",
                "packet_root": str(packet_root.relative_to(REPO_ROOT)),
                "log_root": str(log_root.relative_to(REPO_ROOT)),
                "packet_id": packet_definition["packet_id"],
                "review_gate": gate_state["review_gate"],
                "realization_gate": gate_state["realization_gate"],
                "next_step": gate_state["next_step"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
