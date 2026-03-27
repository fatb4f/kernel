#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ZIP = Path("/home/_404/Downloads/chatgpt-pipeline-operational-packet.zip")
CONTROL_OBJECT_ID = "chatgpt-pipeline-operational-packet"
ZIP_PREFIX = "chatgpt-pipeline-operational-packet/"


def utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def extract_bundle(zip_path: Path, dest: Path) -> None:
    with zipfile.ZipFile(zip_path) as zf:
        for member in zf.infolist():
            name = member.filename
            if not name.startswith(ZIP_PREFIX) or name.endswith("/"):
                continue
            rel = Path(name[len(ZIP_PREFIX):])
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(member) as src, target.open("wb") as out:
                shutil.copyfileobj(src, out)


def run_validator(snapshot_root: Path) -> dict:
    validator = snapshot_root / "local_runtime" / "validate_and_admit.py"
    proc = subprocess.run(
        [sys.executable, str(validator), "generated/packets/pkt-operational-chatgpt-pipeline-001"],
        cwd=snapshot_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "validator failed")
    return json.loads(proc.stdout)


def write_admission_artifacts(snapshot_root: Path, zip_path: Path, run_id: str, result: dict) -> None:
    decision = {
        "artifact_type": "kernel.admission.decision",
        "artifact_version": "0.1.0",
        "control_object_id": CONTROL_OBJECT_ID,
        "run_id": run_id,
        "decision": "ALLOW",
        "summary": "Bundled ChatGPT operational packet validated successfully in snapshot execution.",
        "policy_bundle_id": "chatgpt-pipeline-operational-packet.zip",
        "input_digests": {
            "source_archive": {
                "algorithm": "sha256",
                "value": subprocess.check_output(["sha256sum", str(zip_path)], text=True).split()[0],
            }
        },
        "tool_versions": {
            "python": sys.version.split()[0],
            "validator": "local_runtime/validate_and_admit.py",
        },
        "result": result,
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
        "status": "ADMITTED",
        "packet_id": result["packet_id"],
        "admission": result["admission"],
        "review_gate": result["review_gate"],
        "realization_gate": result["realization_gate"],
        "next_step": result["next_step"],
        "snapshot_root": str(snapshot_root.relative_to(REPO_ROOT)),
    }
    (snapshot_root / "decision.json").write_text(json.dumps(decision, indent=2) + "\n")
    (snapshot_root / "violations.json").write_text(json.dumps(violations, indent=2) + "\n")
    (snapshot_root / "admitted-state.json").write_text(json.dumps(admitted_state, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", dest="zip_path", default=str(DEFAULT_ZIP))
    parser.add_argument("--run-id", dest="run_id", default=utc_run_id())
    args = parser.parse_args()

    zip_path = Path(args.zip_path).resolve()
    snapshot_root = REPO_ROOT / "generated" / "state" / "admission" / CONTROL_OBJECT_ID / args.run_id
    snapshot_root.mkdir(parents=True, exist_ok=False)

    extract_bundle(zip_path, snapshot_root)
    result = run_validator(snapshot_root)
    write_admission_artifacts(snapshot_root, zip_path, args.run_id, result)
    print(json.dumps({"run_id": args.run_id, "snapshot_root": str(snapshot_root), "result": result}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
