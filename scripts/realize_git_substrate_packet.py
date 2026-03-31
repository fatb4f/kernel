#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PACKET_ROOT = REPO_ROOT / "generated" / "packets" / "ps-git-substrate-adapters-v1-001"
DEFAULT_CODEX_RUNNER = (
    REPO_ROOT.parent
    / "dotfiles"
    / "chezmoi"
    / "dot_config"
    / "codex"
    / "control"
    / "proposals"
    / "git_substrate_adapters_v1"
    / "control_realize_git_substrate_adapters_v1.py"
)
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


def run_json(cmd: list[str], cwd: Path) -> tuple[dict, str, str]:
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "command failed")
    return json.loads(result.stdout), result.stdout, result.stderr


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local scm.pattern realization wrapper for the Git-substrate packet.")
    parser.add_argument("--packet-root", default=str(DEFAULT_PACKET_ROOT))
    parser.add_argument("--runner", default=str(DEFAULT_CODEX_RUNNER))
    parser.add_argument("--run-id", default=utc_run_id())
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    packet_root = Path(args.packet_root).resolve()
    runner = Path(args.runner).resolve()
    run_id = args.run_id

    packet_definition_path = packet_root / "machine" / "packet.definition.json"
    packet_definition = load_json(packet_definition_path)
    packet_id = packet_definition["packet_id"]

    validation_run, validation_stdout, validation_stderr = run_json(
        [sys.executable, str(REPO_ROOT / "scripts" / "run_chatgpt_packet_file.py"), str(packet_root)],
        cwd=REPO_ROOT,
    )
    if validation_run["realization_gate"] != "READY_FOR_REALIZATION":
        raise RuntimeError(f"packet is not ready for realization: {validation_run['realization_gate']}")

    run_root = REPO_ROOT / "generated" / "state" / "realization" / CONTROL_OBJECT_ID / packet_id / run_id
    run_root.mkdir(parents=True, exist_ok=False)

    realization_run, realization_stdout, realization_stderr = run_json(
        [sys.executable, str(runner), "--root", str(run_root)],
        cwd=runner.parent,
    )

    manifest_path = Path(realization_run["manifest"]).resolve()
    report_path = Path(realization_run["report"]).resolve()

    execution_log = {
        "artifact_type": "kernel.realization.execution_log",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "packet_id": packet_id,
        "packet_root": rel(packet_root),
        "steps": [
            {
                "name": "validate packet readiness",
                "status": "PASS",
                "runner": "scripts/run_chatgpt_packet_file.py",
                "result": validation_run,
            },
            {
                "name": "realize git substrate slice",
                "status": "PASS",
                "runner": rel(runner),
                "result": realization_run,
            },
        ],
        "stdout": {
            "packet_validation": validation_stdout.strip(),
            "realization": realization_stdout.strip(),
        },
        "stderr": {
            "packet_validation": validation_stderr.strip(),
            "realization": realization_stderr.strip(),
        },
    }

    decision = {
        "artifact_type": "kernel.realization.decision",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "packet_id": packet_id,
        "decision": "ALLOW",
        "summary": "Git-substrate packet realized locally through scm.pattern using the approved packet basis.",
        "packet_validation_run_ref": validation_run["log_root"],
        "realization_manifest_ref": rel(manifest_path),
        "realization_report_ref": rel(report_path),
        "result": {
            "review_gate": validation_run["review_gate"],
            "realization_gate": "REALIZED_VIA_SCM_PATTERN",
            "next_step": "Packet realization outputs are recorded under generated/state/realization/scm.pattern/.",
        },
    }

    realized_state = {
        "artifact_type": "kernel.realized_state",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "packet_id": packet_id,
        "packet_root": rel(packet_root),
        "realization": "PASS",
        "workflow_state": "REALIZED_VIA_SCM_PATTERN",
        "review_state": "DEFINITION_APPROVED",
        "realization_manifest_ref": rel(manifest_path),
        "realization_report_ref": rel(report_path),
        "next_step": "Closeout remains a separate explicit action.",
    }

    violations = {
        "artifact_type": "kernel.realization.violations",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "violations": [],
    }

    (run_root / "execution-log.json").write_text(json.dumps(execution_log, indent=2) + "\n", encoding="utf-8")
    (run_root / "decision.json").write_text(json.dumps(decision, indent=2) + "\n", encoding="utf-8")
    (run_root / "realized-state.json").write_text(json.dumps(realized_state, indent=2) + "\n", encoding="utf-8")
    (run_root / "violations.json").write_text(json.dumps(violations, indent=2) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "run_id": run_id,
                "packet_id": packet_id,
                "run_root": rel(run_root),
                "realization_manifest_ref": rel(manifest_path),
                "realization_report_ref": rel(report_path),
                "workflow_state": "REALIZED_VIA_SCM_PATTERN",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
