from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def run_uv(script: str, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["uv", "run", "--with", "jsonargparse", "--with", "jsonschema", "python", str(ROOT / script), *args],
        cwd=ROOT.parent,
        text=True,
        capture_output=True,
        check=False,
    )


def test_packet_file_jsonargparse_help() -> None:
    result = run_uv("run_chatgpt_packet_file_jsonargparse.py", "--help")
    assert result.returncode == 0, result.stderr
    assert "run-chatgpt-packet-file" in result.stdout
    assert "--execute" in result.stdout


def test_packet_file_jsonargparse_dry_run() -> None:
    result = run_uv(
        "run_chatgpt_packet_file_jsonargparse.py",
        "generated/packets/ps-git-substrate-adapters-v1-001",
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["packet_id"]
    assert payload["review_gate"] == "PASS"


def test_problem_set_jsonargparse_help() -> None:
    result = run_uv("run_problem_set_surface_jsonargparse.py", "--help")
    assert result.returncode == 0, result.stderr
    assert "problem_set" in result.stdout
