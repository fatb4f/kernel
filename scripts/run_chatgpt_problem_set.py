#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_ROOT = REPO_ROOT / "generated" / "schemas" / "chatgpt-pipeline" / "workflow"
DEFAULT_PROBLEM_SET = (
    REPO_ROOT / "generated" / "problem_sets" / "ps-operationalize-chatgpt-pipeline-001" / "problem_set.json"
)
CONTROL_OBJECT_ID = "chatgpt-problem-set-runner"
PACKET_RUNNER = REPO_ROOT / "scripts" / "run_chatgpt_packet_file.py"


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def canonical_json_bytes(instance: object) -> bytes:
    return (json.dumps(instance, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def dump_json(path: Path, instance: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(instance, indent=2) + "\n")


def validate_problem_set(problem_set_path: Path) -> dict:
    schema = load_json(WORKFLOW_ROOT / "problem_set.schema.json")
    instance = load_json(problem_set_path)
    Draft202012Validator(schema).validate(instance)
    return instance


def normalized_problem_set(problem_set: dict) -> dict:
    normalized = copy.deepcopy(problem_set)
    normalized.setdefault("change_control", {"normalized_json": True, "stale_when": []})
    normalized.setdefault("fingerprint", {"algorithm": "sha256", "value": "pending_generation"})
    return normalized


def compute_problem_set_fingerprint(problem_set: dict) -> str:
    basis = copy.deepcopy(problem_set)
    basis.pop("fingerprint", None)
    return sha256_bytes(canonical_json_bytes(basis))


def packet_id_for(problem_set_id: str) -> str:
    if problem_set_id.startswith("ps-"):
        return "pkt-" + problem_set_id[3:]
    return "pkt-" + problem_set_id


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def build_packet_definition(problem_set: dict, problem_set_ref: str, packet_root_ref: str) -> dict:
    packet_id = packet_root_ref.split("/")[-1]
    machine_root = f"{packet_root_ref}/machine"
    human_root = f"{packet_root_ref}/human"
    workflow_manifest_ref = "generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json"
    execution_policy_ref = "generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json"
    validation_manifest_ref = "generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json"
    gate_policy_ref = "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json"
    problem_set_schema_ref = "generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json"
    packet_schema_refs = [
        "generated/schemas/chatgpt-pipeline/packet/packet.definition.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/scm.pattern.binding.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/packet.review.request.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/root.trust.evidence.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/regen.record.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/artifact.manifest.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/packet.approval.schema.json",
        "generated/schemas/chatgpt-pipeline/packet/packet.review.decision.schema.json",
    ]
    required_now = [
        {"ref": f"{machine_root}/packet.definition.json", "kind": "packet_definition"},
        {"ref": f"{machine_root}/scm.pattern.binding.json", "kind": "scm_pattern_binding"},
        {"ref": f"{machine_root}/packet.review.request.json", "kind": "packet_review_request"},
        {"ref": f"{machine_root}/root.trust.evidence.json", "kind": "root_trust_evidence"},
        {"ref": f"{machine_root}/regen.record.json", "kind": "regen_record"},
        {"ref": f"{machine_root}/artifact.manifest.json", "kind": "artifact_manifest"},
        {
            "ref": f"{machine_root}/packet.approval.json",
            "kind": "compatibility_placeholder",
            "transitional": True,
            "authoritative": False,
        },
        {"ref": f"{human_root}/packet.definition.md", "kind": "derived_human_definition"},
    ]
    conditional = [
        {
            "ref": f"{machine_root}/packet.review.decision.json",
            "kind": "packet_review_decision",
            "required_when": "human_review_decision_issued == true",
        }
    ]
    return {
        "artifact_type": "gpt_handoff.packet.definition",
        "artifact_version": "0.2.0",
        "spec_ref": workflow_manifest_ref,
        "packet_id": packet_id,
        "title": problem_set["identity"]["title"],
        "workflow_state": "DEFINITION_UNDER_REVIEW",
        "review_state": "DEFINITION_UNDER_REVIEW",
        "summary": (
            "Packet generated from a single problem_set ingress. "
            "It emits the canonical machine and human packet artifacts, "
            "passes through local dry-run admission, and blocks realization until "
            "an authoritative human review decision exists."
        ),
        "ownership": {
            "authority_owner": "kernel",
            "packet_author": "chatgpt_problem_set_runner",
            "validation_owner": "local_runtime",
            "realization_owner": "scm.pattern",
        },
        "constraints": list(problem_set.get("constraints", []))
        + [
            "No hidden secondary plan or implement artifacts are allowed.",
            "packet.approval.json is transitional and non-authoritative.",
            "Realization is blocked until packet.review.decision.json exists and is authoritative.",
        ],
        "realization": {
            "local_realization_surface": "scm.pattern",
            "canonical_packet_root": packet_root_ref,
            "repo_relative_paths_only": True,
            "chatgpt_may_realize": False,
        },
        "inputs": [
            {"ref": problem_set_ref, "role": "problem_set"},
            {"ref": problem_set_schema_ref, "role": "ingress_contract"},
            {"ref": workflow_manifest_ref, "role": "pipeline_manifest"},
            {"ref": execution_policy_ref, "role": "execution_policy"},
            {"ref": validation_manifest_ref, "role": "validation_manifest"},
            {"ref": gate_policy_ref, "role": "gate_policy"},
            {"ref": "control/scm.pattern/authority.manifest.json", "role": "authority_manifest"},
            {"ref": "control/trust/root.signers.json", "role": "root_signers"},
            {"ref": "control/trust/delegations/chatgpt.packet-sidecar.json", "role": "delegation"},
        ]
        + [{"ref": ref, "role": "packet_schema"} for ref in packet_schema_refs],
        "deliverables": {
            "required_now": required_now,
            "conditional": conditional,
        },
        "kernel_trust_requirements": {
            "root_signers_ref": "control/trust/root.signers.json",
            "authority_manifest_ref": "control/scm.pattern/authority.manifest.json",
            "authority_manifest_validation_ref": "control/scm.pattern/authority.manifest.validation.json",
            "authority_manifest_signature_ref": "control/scm.pattern/authority.manifest.signature.json",
            "delegation_ref": "control/trust/delegations/chatgpt.packet-sidecar.json",
            "packet_local_evidence_ref": f"{machine_root}/root.trust.evidence.json",
        },
        "review_lifecycle": {
            "review_request_ref": f"{machine_root}/packet.review.request.json",
            "review_decision_ref": f"{machine_root}/packet.review.decision.json",
            "current_gate": "AWAITING_HUMAN_REVIEW",
            "allowed_outcomes": ["APPROVED", "REVISE", "REJECTED"],
            "non_authoritative_placeholder_ref": f"{machine_root}/packet.approval.json",
        },
        "admissibility_rules": [
            "problem_set is the only admissible operational ingress.",
            "Packet generation must emit the canonical machine and human artifact set.",
            "Execution policy, validation manifest, and gate policy must all be evaluated locally.",
            "No packet may realize before an authoritative review decision exists.",
            "Generated instances never mutate authority.",
        ],
        "staleness_rules": {
            "stale_when": problem_set.get("change_control", {}).get("stale_when", []),
            "formatting_only_changes_do_not_stale": True,
        },
        "regeneration": {
            "policy_ref": execution_policy_ref,
            "regen_record_ref": f"{machine_root}/regen.record.json",
            "skip_when_inputs_unchanged": True,
        },
    }


def build_binding(packet_definition: dict, packet_root_ref: str, problem_set_ref: str) -> dict:
    machine_root = f"{packet_root_ref}/machine"
    return {
        "artifact_type": "gpt_handoff.scm_pattern.binding",
        "artifact_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "surface": "scm.pattern",
        "authority_manifest_ref": "control/scm.pattern/authority.manifest.json",
        "authority_manifest_schema_ref": "generated/schemas/chatgpt-pipeline/packet/authority.manifest.schema.json",
        "kernel_trust": {
            "root_trust_evidence_ref": f"{machine_root}/root.trust.evidence.json",
            "root_signers_ref": "control/trust/root.signers.json",
            "root_delegation_ref": "control/trust/delegations/chatgpt.packet-sidecar.json",
            "authority_manifest_validation_ref": "control/scm.pattern/authority.manifest.validation.json",
            "authority_manifest_signature_ref": "control/scm.pattern/authority.manifest.signature.json",
        },
        "realization_scope": {
            "write_paths": [item["ref"] for item in packet_definition["deliverables"]["required_now"]],
            "conditional_write_paths": [item["ref"] for item in packet_definition["deliverables"]["conditional"]],
            "read_paths": [problem_set_ref]
            + [item["ref"] for item in packet_definition["inputs"] if item["ref"] != problem_set_ref]
            + [
                "control/scm.pattern/authority.manifest.validation.json",
                "control/scm.pattern/authority.manifest.signature.json",
            ],
        },
        "human_intervention_points": [
            "Issue packet.review.decision.json after reviewing the request and basis refs.",
            "Permit local realization only after an APPROVED human decision is present.",
        ],
        "promotion_constraints": [
            "No promotion without human-issued review decision.",
            "Stale approval basis blocks promotion.",
            "Direct publish remains outside the generation policy.",
        ],
        "repo_relative_packet_root": packet_root_ref,
        "notes": "Local runtime may admit the generated packet structurally before human review, but realization remains blocked.",
    }


def build_review_request(packet_definition: dict, packet_root_ref: str, problem_set_ref: str) -> dict:
    machine_root = f"{packet_root_ref}/machine"
    return {
        "artifact_type": "gpt_handoff.packet.review.request",
        "artifact_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "submitted_by": {"role": "chatgpt_problem_set_runner"},
        "review_scope": "definition_and_admission_boundary",
        "requested_outcomes": ["APPROVED", "REVISE", "REJECTED"],
        "review_basis_refs": [
            f"{machine_root}/packet.definition.json",
            f"{machine_root}/scm.pattern.binding.json",
            f"{machine_root}/root.trust.evidence.json",
            f"{machine_root}/artifact.manifest.json",
            problem_set_ref,
            "generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json",
            "generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json",
            "generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json",
            "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json",
        ],
        "kernel_trust": {
            "authority_manifest_ref": "control/scm.pattern/authority.manifest.json",
            "authority_manifest_validation_ref": "control/scm.pattern/authority.manifest.validation.json",
            "authority_manifest_signature_ref": "control/scm.pattern/authority.manifest.signature.json",
            "delegation_ref": "control/trust/delegations/chatgpt.packet-sidecar.json",
            "root_trust_evidence_ref": f"{machine_root}/root.trust.evidence.json",
        },
        "human_action_required": True,
        "approval_authority": False,
        "artifact_status": "REVIEW_REQUEST_SUBMITTED",
    }


def build_root_trust(packet_definition: dict, packet_root_ref: str) -> dict:
    refs = {
        "root_signers_ref": "control/trust/root.signers.json",
        "root_delegation_ref": "control/trust/delegations/chatgpt.packet-sidecar.json",
        "authority_manifest_ref": "control/scm.pattern/authority.manifest.json",
        "authority_manifest_validation_ref": "control/scm.pattern/authority.manifest.validation.json",
        "authority_manifest_signature_ref": "control/scm.pattern/authority.manifest.signature.json",
        "pipeline_manifest_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json",
        "execution_policy_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json",
        "validation_manifest_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json",
        "gate_policy_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json",
        "problem_set_schema_ref": "generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json",
    }
    fingerprints = {}
    for key, ref in refs.items():
        normalized_key = key.removesuffix("_ref")
        fingerprints[normalized_key] = {
            "algorithm": "sha256",
            "value": sha256_path(REPO_ROOT / ref),
        }
    return {
        "artifact_type": "gpt_handoff.root.trust.evidence",
        "artifact_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "canonical_refs": refs,
        "canonical_fingerprints": fingerprints,
        "evidence_requirements": {
            "all_refs_must_resolve": True,
            "all_fingerprints_must_match": True,
            "signature_must_verify": True,
            "delegation_must_be_in_scope": True,
        },
        "status": "DECLARED_REQUIRED_EVIDENCE",
    }


def build_packet_approval(packet_definition: dict, packet_root_ref: str) -> dict:
    return {
        "artifact_type": "gpt_handoff.packet.approval",
        "artifact_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "verdict": "PENDING_HUMAN_DECISION",
        "approval_authority": False,
        "human_action_required": True,
        "artifact_status": "TRANSITIONAL_COMPATIBILITY_PLACEHOLDER",
        "issued_by": {"role": "chatgpt_problem_set_runner"},
        "canonical_review_artifact_ref": f"{packet_root_ref}/machine/packet.review.request.json",
        "authoritative_review_state": False,
        "does_not_satisfy_realization_gate": True,
    }


def build_human_markdown(packet_definition: dict, problem_set_ref: str) -> str:
    required_now = "\n".join(f"- {item['ref']}" for item in packet_definition["deliverables"]["required_now"])
    conditional = "\n".join(f"- {item['ref']}" for item in packet_definition["deliverables"]["conditional"])
    inputs = "\n".join(f"- {item['ref']}" for item in packet_definition["inputs"])
    constraints = "\n".join(f"- {item}" for item in packet_definition["constraints"])
    return f"""# Packet Definition — {packet_definition['packet_id']}

## Title
{packet_definition['title']}

## Status
- workflow_state: {packet_definition['workflow_state']}
- review_state: {packet_definition['review_state']}

## Summary
{packet_definition['summary']}

This packet is generated from `problem_set` ingress at `{problem_set_ref}`.
It is intended for review-first execution and blocks realization until an
authoritative review decision exists.

## Inputs
{inputs}

## Constraints
{constraints}

## Required artifacts now
{required_now}

## Conditional later
{conditional}

## Admission boundary
- Local runtime validates all required artifacts and refs
- Trust evidence fingerprints must match current file content
- Admission may pass before human review, but realization may not
- Human-issued review decision remains required for realization
"""


def build_artifact_manifest(packet_definition: dict) -> dict:
    return {
        "artifact_type": "gpt_handoff.artifact.manifest",
        "artifact_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "workflow_state": packet_definition["workflow_state"],
        "review_state": packet_definition["review_state"],
        "required_artifacts": packet_definition["deliverables"]["required_now"],
        "conditional_artifacts": packet_definition["deliverables"]["conditional"],
        "supporting_inputs": [item["ref"] for item in packet_definition["inputs"][:3]],
    }


def build_regen_record(packet_definition: dict, packet_root: Path, problem_set_ref: str) -> dict:
    machine_root = packet_root / "machine"
    human_root = packet_root / "human"
    named_outputs = {
        "packet.definition.json": machine_root / "packet.definition.json",
        "scm.pattern.binding.json": machine_root / "scm.pattern.binding.json",
        "packet.review.request.json": machine_root / "packet.review.request.json",
        "root.trust.evidence.json": machine_root / "root.trust.evidence.json",
        "artifact.manifest.json": machine_root / "artifact.manifest.json",
        "packet.approval.json": machine_root / "packet.approval.json",
        "packet.definition.md": human_root / "packet.definition.md",
    }
    output_fingerprints = {name: sha256_path(path) for name, path in named_outputs.items()}
    approval_basis = sha256_bytes(
        canonical_json_bytes(load_json(machine_root / "packet.definition.json"))
        + canonical_json_bytes(load_json(machine_root / "scm.pattern.binding.json"))
        + canonical_json_bytes(load_json(machine_root / "packet.review.request.json"))
        + canonical_json_bytes(load_json(machine_root / "root.trust.evidence.json"))
    )
    return {
        "kind": "gpt_handoff.regen.record",
        "spec_version": "0.2.0",
        "packet_id": packet_definition["packet_id"],
        "policy": "Regeneration is blocked unless required inputs change materially.",
        "required_inputs": {
            "problem_set_ref": problem_set_ref,
            "authority_manifest_ref": "control/scm.pattern/authority.manifest.json",
            "authority_manifest_schema_ref": "generated/schemas/chatgpt-pipeline/packet/authority.manifest.schema.json",
            "pipeline_manifest_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json",
            "execution_policy_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json",
            "validation_manifest_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json",
            "gate_policy_ref": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json",
        },
        "output_fingerprints": output_fingerprints,
        "approval_basis_fingerprint": approval_basis,
        "status": "GENERATED",
        "notes": "Formatting-only changes do not stale approval basis. Human review decision, if issued later, must target the approval basis fingerprint recorded here.",
    }


def write_generated_packet(problem_set: dict, problem_set_path: Path) -> tuple[Path, dict]:
    packet_id = packet_id_for(problem_set["problem_set_id"])
    packet_root = REPO_ROOT / "generated" / "packets" / packet_id
    machine_root = packet_root / "machine"
    human_root = packet_root / "human"
    machine_root.mkdir(parents=True, exist_ok=True)
    human_root.mkdir(parents=True, exist_ok=True)

    problem_set_ref = rel(problem_set_path)
    packet_root_ref = rel(packet_root)

    packet_definition = build_packet_definition(problem_set, problem_set_ref, packet_root_ref)
    binding = build_binding(packet_definition, packet_root_ref, problem_set_ref)
    review_request = build_review_request(packet_definition, packet_root_ref, problem_set_ref)
    root_trust = build_root_trust(packet_definition, packet_root_ref)
    packet_approval = build_packet_approval(packet_definition, packet_root_ref)
    human_markdown = build_human_markdown(packet_definition, problem_set_ref)
    artifact_manifest = build_artifact_manifest(packet_definition)

    dump_json(machine_root / "packet.definition.json", packet_definition)
    dump_json(machine_root / "scm.pattern.binding.json", binding)
    dump_json(machine_root / "packet.review.request.json", review_request)
    dump_json(machine_root / "root.trust.evidence.json", root_trust)
    dump_json(machine_root / "artifact.manifest.json", artifact_manifest)
    dump_json(machine_root / "packet.approval.json", packet_approval)
    (human_root / "packet.definition.md").write_text(human_markdown)

    regen_record = build_regen_record(packet_definition, packet_root, problem_set_ref)
    dump_json(machine_root / "regen.record.json", regen_record)

    return packet_root, {
        "packet_definition": packet_definition,
        "scm_pattern_binding": binding,
        "packet_review_request": review_request,
        "root_trust_evidence": root_trust,
        "artifact_manifest": artifact_manifest,
        "packet_approval": packet_approval,
        "regen_record": regen_record,
    }


def write_problem_set(problem_set_path: Path, problem_set: dict) -> None:
    dump_json(problem_set_path, problem_set)


def run_packet_validator(packet_root: Path, run_id: str) -> dict:
    proc = subprocess.run(
        [
            sys.executable,
            str(PACKET_RUNNER),
            str(packet_root.relative_to(REPO_ROOT)),
            "--run-id",
            run_id,
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "packet runner failed")
    return json.loads(proc.stdout)


def write_log_artifacts(
    run_id: str,
    dry_run: bool,
    problem_set_path: Path,
    problem_set: dict,
    packet_root: Path,
    generated_refs: dict,
    packet_run_result: dict,
) -> Path:
    log_root = REPO_ROOT / "generated" / "state" / "admission" / CONTROL_OBJECT_ID / run_id
    log_root.mkdir(parents=True, exist_ok=False)

    execution_log = {
        "artifact_type": "kernel.chatgpt_problem_set_runner_log",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "mode": "DRY_RUN" if dry_run else "EXECUTE",
        "problem_set_ref": rel(problem_set_path),
        "problem_set_id": problem_set["problem_set_id"],
        "packet_root": rel(packet_root),
        "steps": [
            {
                "name": "validate problem_set schema",
                "status": "PASS",
                "schema": "generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json",
            },
            {
                "name": "normalize and fingerprint problem_set",
                "status": "PASS",
                "fingerprint": problem_set["fingerprint"],
            },
            {
                "name": "generate canonical packet artifacts",
                "status": "PASS",
                "artifacts": {
                    name: f"{rel(packet_root)}/machine/{filename}"
                    for name, filename in [
                        ("packet_definition", "packet.definition.json"),
                        ("scm_pattern_binding", "scm.pattern.binding.json"),
                        ("packet_review_request", "packet.review.request.json"),
                        ("root_trust_evidence", "root.trust.evidence.json"),
                        ("regen_record", "regen.record.json"),
                        ("artifact_manifest", "artifact.manifest.json"),
                        ("packet_approval", "packet.approval.json"),
                    ]
                },
            },
            {
                "name": "invoke packet-file dry-run admission",
                "status": "PASS",
                "packet_runner_result": packet_run_result,
            },
        ],
        "generated_refs": generated_refs,
        "planned_actions": [
            "No realization during dry-run generation.",
            "Packet generation is allowed; realization remains blocked.",
            "Authoritative packet.review.decision.json is still required for realization.",
        ],
    }

    decision = {
        "artifact_type": "kernel.admission.decision",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "decision": "ALLOW",
        "summary": "problem_set ingress generated a canonical packet and passed local dry-run admission.",
        "policy_bundle_id": "generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json",
        "input_digests": {
            "problem_set": problem_set["fingerprint"],
        },
        "tool_versions": {
            "python": sys.version.split()[0],
            "runner": "scripts/run_chatgpt_problem_set.py",
            "packet_runner": "scripts/run_chatgpt_packet_file.py",
        },
        "result": packet_run_result,
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
        "problem_set_id": problem_set["problem_set_id"],
        "packet_id": packet_run_result["packet_id"],
        "packet_root": packet_run_result["packet_root"],
        "admission": "PASS",
        "review_gate": packet_run_result["review_gate"],
        "realization_gate": packet_run_result["realization_gate"],
        "next_step": packet_run_result["next_step"],
        "packet_runner_log_root": packet_run_result["log_root"],
    }

    dump_json(log_root / "execution-log.json", execution_log)
    dump_json(log_root / "decision.json", decision)
    dump_json(log_root / "violations.json", violations)
    dump_json(log_root / "admitted-state.json", admitted_state)
    return log_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate and admit a canonical packet from a problem_set.")
    parser.add_argument("problem_set", nargs="?", default=str(DEFAULT_PROBLEM_SET.relative_to(REPO_ROOT)))
    parser.add_argument("--run-id", default=utc_run_id())
    parser.add_argument("--execute", action="store_true", help="Reserved for future non-dry-run realization.")
    args = parser.parse_args()

    problem_set_path = (REPO_ROOT / args.problem_set).resolve() if not Path(args.problem_set).is_absolute() else Path(args.problem_set)
    problem_set = normalized_problem_set(validate_problem_set(problem_set_path))
    fingerprint = compute_problem_set_fingerprint(problem_set)
    problem_set["fingerprint"] = {"algorithm": "sha256", "value": fingerprint}
    write_problem_set(problem_set_path, problem_set)

    packet_root, generated_refs = write_generated_packet(problem_set, problem_set_path)
    packet_run_result = run_packet_validator(packet_root, args.run_id)
    log_root = write_log_artifacts(
        run_id=args.run_id,
        dry_run=not args.execute,
        problem_set_path=problem_set_path,
        problem_set=problem_set,
        packet_root=packet_root,
        generated_refs=generated_refs,
        packet_run_result=packet_run_result,
    )

    print(
        json.dumps(
            {
                "run_id": args.run_id,
                "mode": "DRY_RUN" if not args.execute else "EXECUTE",
                "problem_set_ref": rel(problem_set_path),
                "packet_root": rel(packet_root),
                "log_root": rel(log_root),
                "packet_runner_log_root": packet_run_result["log_root"],
                "review_gate": packet_run_result["review_gate"],
                "realization_gate": packet_run_result["realization_gate"],
                "next_step": packet_run_result["next_step"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
