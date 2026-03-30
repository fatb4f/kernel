#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PACKET_ROOT = REPO_ROOT / "generated" / "packets" / "ps-git-substrate-adapters-v1-001"
CONTROL_OBJECT_ID = "scm.pattern"


def utc_run_id() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(REPO_ROOT))
    except ValueError:
        return str(resolved)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local scm.pattern closeout wrapper for the Git-substrate packet.")
    parser.add_argument("--packet-root", default=str(DEFAULT_PACKET_ROOT))
    parser.add_argument("--realization-run-root")
    parser.add_argument("--run-id", default=utc_run_id())
    return parser.parse_args(argv)


def find_latest_realization(packet_id: str) -> Path:
    base = REPO_ROOT / "generated" / "state" / "realization" / CONTROL_OBJECT_ID / packet_id
    if not base.exists():
        raise FileNotFoundError(f"no realization runs found for {packet_id}")
    runs = sorted(path for path in base.iterdir() if path.is_dir())
    if not runs:
        raise FileNotFoundError(f"no realization runs found for {packet_id}")
    return runs[-1]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    packet_root = Path(args.packet_root).resolve()
    packet_definition = load_json(packet_root / "machine" / "packet.definition.json")
    packet_id = packet_definition["packet_id"]

    realization_root = (
        Path(args.realization_run_root).resolve()
        if args.realization_run_root
        else find_latest_realization(packet_id)
    )
    realized_state_path = realization_root / "realized-state.json"
    realization_decision_path = realization_root / "decision.json"
    realization_report_path = realization_root / "build" / "realization_report.json"
    realization_manifest_path = realization_root / "build" / "realization_manifest.json"
    if not realized_state_path.exists():
        raise FileNotFoundError(f"missing realized-state.json in {realization_root}")

    realized_state = load_json(realized_state_path)
    if realized_state.get("workflow_state") != "REALIZED_VIA_SCM_PATTERN":
        raise ValueError("realization run is not in REALIZED_VIA_SCM_PATTERN")
    if realized_state.get("realization") != "PASS":
        raise ValueError("realization run did not pass")

    closeout_root = REPO_ROOT / "generated" / "state" / "closeout" / CONTROL_OBJECT_ID / packet_id / args.run_id
    closeout_root.mkdir(parents=True, exist_ok=False)

    execution_log = {
        "artifact_type": "kernel.closeout.execution_log",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": args.run_id,
        "packet_id": packet_id,
        "packet_root": rel(packet_root),
        "steps": [
            {
                "name": "resolve realization run",
                "status": "PASS",
                "realization_run_root": rel(realization_root),
            },
            {
                "name": "verify realization status",
                "status": "PASS",
                "workflow_state": realized_state["workflow_state"],
                "realization": realized_state["realization"],
            },
            {
                "name": "close packet runtime state",
                "status": "PASS",
                "closeout_state": "CLOSED",
            },
        ],
    }

    decision = {
        "artifact_type": "kernel.closeout.decision",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": args.run_id,
        "packet_id": packet_id,
        "decision": "ALLOW",
        "summary": "Git-substrate packet closeout is recorded from an already successful scm.pattern realization run.",
        "realization_run_ref": rel(realization_root),
        "realization_decision_ref": rel(realization_decision_path),
        "realization_manifest_ref": rel(realization_manifest_path),
        "realization_report_ref": rel(realization_report_path),
        "result": {
            "workflow_state": "CLOSED",
            "review_state": "DEFINITION_APPROVED",
            "next_step": "Packet closeout is recorded under generated/state/closeout/scm.pattern/.",
        },
    }

    closed_state = {
        "artifact_type": "kernel.closed_state",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": args.run_id,
        "packet_id": packet_id,
        "packet_root": rel(packet_root),
        "closeout": "PASS",
        "workflow_state": "CLOSED",
        "review_state": "DEFINITION_APPROVED",
        "realization_run_ref": rel(realization_root),
        "realization_manifest_ref": rel(realization_manifest_path),
        "realization_report_ref": rel(realization_report_path),
        "summary": "The Git-substrate packet has an explicit scm.pattern realization run and is now closed at the local runtime layer.",
    }

    violations = {
        "artifact_type": "kernel.closeout.violations",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": args.run_id,
        "violations": [],
    }

    (closeout_root / "execution-log.json").write_text(json.dumps(execution_log, indent=2) + "\n", encoding="utf-8")
    (closeout_root / "decision.json").write_text(json.dumps(decision, indent=2) + "\n", encoding="utf-8")
    (closeout_root / "closed-state.json").write_text(json.dumps(closed_state, indent=2) + "\n", encoding="utf-8")
    (closeout_root / "violations.json").write_text(json.dumps(violations, indent=2) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "run_id": args.run_id,
                "packet_id": packet_id,
                "closeout_root": rel(closeout_root),
                "workflow_state": "CLOSED",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
