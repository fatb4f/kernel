#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_ROOT = REPO_ROOT / "generated" / "schemas" / "chatgpt-pipeline" / "workflow"
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "generated" / "problem_sets"


def canonical_json_bytes(instance: object) -> bytes:
    return (json.dumps(instance, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def dump_json(path: Path, instance: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(instance, indent=2) + "\n")


def rel(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT))


def validate_instance(schema_path: Path, instance: dict) -> None:
    schema = load_json(schema_path)
    Draft202012Validator(schema).validate(instance)


def normalize_authoring(authoring: dict) -> dict:
    normalized = {
        "kind": "kernel.problem_set",
        "problem_set_id": authoring["problem_set_id"],
        "version": authoring.get("version", "0.3.0"),
        "status": authoring.get("status", "draft"),
        "identity": copy.deepcopy(authoring["identity"]),
        "objective": authoring["objective"].strip(),
        "scope": {
            "in_scope": list(authoring["scope"]["in_scope"]),
            "out_of_scope": list(authoring["scope"]["out_of_scope"]),
        },
        "constraints": list(authoring.get("constraints", [])),
        "assumptions": list(authoring.get("assumptions", [])),
        "requested_outputs": list(authoring.get("requested_outputs", [])),
        "authority_refs": list(authoring.get("authority_refs", [])),
        "acceptance_criteria": list(authoring.get("acceptance_criteria", [])),
    }

    if "review_criteria" in authoring:
        normalized["review_criteria"] = list(authoring["review_criteria"])

    if "scope_controls" in authoring:
        normalized["scope_controls"] = copy.deepcopy(authoring["scope_controls"])

    if "handoff" in authoring:
        normalized["handoff"] = copy.deepcopy(authoring["handoff"])

    normalized["change_control"] = copy.deepcopy(
        authoring.get(
            "change_control",
            {
                "normalized_json": True,
                "stale_when": [
                    "problem_set fingerprint change",
                    "authority ref change",
                    "acceptance criteria change",
                ],
            },
        )
    )

    basis = copy.deepcopy(normalized)
    basis.pop("fingerprint", None)
    normalized["fingerprint"] = {
        "algorithm": "sha256",
        "value": sha256_bytes(canonical_json_bytes(basis)),
    }
    return normalized


def build_issue_title(problem_set: dict) -> str:
    prefix = problem_set.get("handoff", {}).get("issue_title_prefix", "Packet handoff")
    return f"{prefix}: {problem_set['problem_set_id']} - {problem_set['identity']['title']}"


def build_issue_marker(problem_set_id: str) -> str:
    return f"<!-- kernel-problem-set:{problem_set_id} -->"


def build_issue_body(problem_set: dict, repo: str) -> str:
    marker = build_issue_marker(problem_set["problem_set_id"])
    scope_controls = problem_set.get("scope_controls", {})
    lines = [
        marker,
        f"# {problem_set['identity']['title']}",
        "",
        "## Contract",
        f"- `problem_set_id`: `{problem_set['problem_set_id']}`",
        f"- `status`: `{problem_set['status']}`",
        f"- `version`: `{problem_set['version']}`",
        f"- `fingerprint`: `{problem_set['fingerprint']['value']}`",
        f"- `repo`: `{repo}`",
        "",
        "## Objective",
        problem_set["objective"],
        "",
        "## In Scope",
    ]
    lines.extend(f"- {item}" for item in problem_set["scope"]["in_scope"])
    lines.extend(["", "## Out Of Scope"])
    lines.extend(f"- {item}" for item in problem_set["scope"]["out_of_scope"])

    if scope_controls:
        lines.extend(["", "## Scope Controls"])
        for key in [
            "target_repos",
            "forbidden_repos",
            "target_surfaces",
            "forbidden_surfaces",
            "target_artifact_classes",
            "forbidden_artifact_classes",
        ]:
            values = scope_controls.get(key, [])
            if values:
                lines.append(f"- `{key}`:")
                lines.extend(f"  - {item}" for item in values)

    lines.extend(["", "## Constraints"])
    lines.extend(f"- {item}" for item in problem_set.get("constraints", []))
    lines.extend(["", "## Requested Outputs"])
    lines.extend(f"- {item}" for item in problem_set.get("requested_outputs", []))
    lines.extend(["", "## Authority Refs"])
    lines.extend(f"- `{item}`" for item in problem_set.get("authority_refs", []))
    lines.extend(["", "## Acceptance Criteria"])
    lines.extend(f"- {item}" for item in problem_set.get("acceptance_criteria", []))

    review = problem_set.get("review_criteria", [])
    if review:
        lines.extend(["", "## Review Criteria"])
        lines.extend(f"- {item}" for item in review)

    lines.extend(
        [
            "",
            "## Handoff",
            "- ChatGPT authors the packet handoff artifact from this normalized problem_set.",
            "- Local runtime validates and admits the generated packet.",
            "- Human review remains authoritative before promotion or realization.",
            "",
            "## Automation",
            f"- Generated from `generated/problem_sets/{problem_set['problem_set_id']}/problem_set.json`.",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize a JSON-authored problem_set and render handoff issue content.")
    sub = parser.add_subparsers(dest="command", required=True)

    normalize = sub.add_parser("normalize", help="Normalize authoring JSON into generated/problem_sets/<id>/problem_set.json")
    normalize.add_argument("source", type=Path, help="Path to JSON-authored problem_set source")
    normalize.add_argument(
        "--output-root",
        type=Path,
        default=DEFAULT_OUTPUT_ROOT,
        help="Root directory for normalized problem_set outputs",
    )
    normalize.add_argument(
        "--stdout",
        action="store_true",
        help="Write normalized JSON to stdout instead of a file",
    )

    issue = sub.add_parser("issue-body", help="Render the GitHub issue body for a normalized problem_set")
    issue.add_argument("problem_set", type=Path, help="Path to normalized generated/problem_set.json")
    issue.add_argument("--repo", required=True, help="GitHub owner/repo used in the handoff issue body")

    title = sub.add_parser("issue-title", help="Render the GitHub issue title for a normalized problem_set")
    title.add_argument("problem_set", type=Path, help="Path to normalized generated/problem_set.json")

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.command == "normalize":
        authoring = load_json(args.source)
        validate_instance(WORKFLOW_ROOT / "problem_set.authoring.schema.json", authoring)
        normalized = normalize_authoring(authoring)
        validate_instance(WORKFLOW_ROOT / "problem_set.schema.json", normalized)
        if args.stdout:
            sys.stdout.write(json.dumps(normalized, indent=2) + "\n")
            return 0
        output_dir = args.output_root / normalized["problem_set_id"]
        output_path = output_dir / "problem_set.json"
        dump_json(output_path, normalized)
        print(rel(output_path))
        return 0

    problem_set = load_json(args.problem_set)
    validate_instance(WORKFLOW_ROOT / "problem_set.schema.json", problem_set)
    if args.command == "issue-body":
        sys.stdout.write(build_issue_body(problem_set, args.repo))
        return 0
    if args.command == "issue-title":
        print(build_issue_title(problem_set))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
