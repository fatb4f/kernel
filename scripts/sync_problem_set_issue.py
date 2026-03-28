#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

from author_problem_set import (
    WORKFLOW_ROOT,
    build_issue_body,
    build_issue_marker,
    build_issue_title,
    load_json,
    rel,
    validate_instance,
)


REPO_ROOT = Path(__file__).resolve().parents[1]


def gh_json(*args: str) -> object:
    result = subprocess.run(
        ["gh", *args],
        cwd=REPO_ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def gh(*args: str) -> None:
    subprocess.run(["gh", *args], cwd=REPO_ROOT, check=True)


def find_existing_issue(repo: str, problem_set_id: str) -> dict | None:
    marker = build_issue_marker(problem_set_id)
    issues = gh_json(
        "issue",
        "list",
        "--repo",
        repo,
        "--state",
        "all",
        "--json",
        "number,title,body,url",
        "--limit",
        "200",
    )
    for issue in issues:
        if marker in issue.get("body", ""):
            return issue

    prefix = f": {problem_set_id} - "
    for issue in issues:
        if prefix in issue.get("title", ""):
            return issue
    return None


def write_temp_file(contents: str, suffix: str) -> str:
    fd, path = tempfile.mkstemp(prefix="problem-set-issue-", suffix=".md")
    with os.fdopen(fd, "w") as handle:
        handle.write(contents)
    return path


def write_payload(title: str, body: str, labels: list[str], assignees: list[str]) -> str:
    fd, path = tempfile.mkstemp(prefix="problem-set-issue-", suffix=".json")
    payload = {
        "title": title,
        "body": body,
        "labels": labels,
        "assignees": assignees,
    }
    with os.fdopen(fd, "w") as handle:
        json.dump(payload, handle)
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create or update the GitHub handoff issue for a normalized problem_set.")
    parser.add_argument("problem_set", type=Path, help="Path to normalized generated/problem_set.json")
    parser.add_argument("--repo", required=True, help="GitHub owner/repo")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    problem_set = load_json(args.problem_set)
    validate_instance(WORKFLOW_ROOT / "problem_set.schema.json", problem_set)

    title = build_issue_title(problem_set)
    body = build_issue_body(problem_set, args.repo)
    labels = list(problem_set.get("handoff", {}).get("labels", ["packet-handoff", "problem-set"]))
    assignees = list(problem_set.get("handoff", {}).get("assignees", []))

    issue = find_existing_issue(args.repo, problem_set["problem_set_id"])
    payload_file = write_payload(title, body, labels, assignees)
    try:
        if issue is None:
            gh(
                "api",
                f"repos/{args.repo}/issues",
                "--method",
                "POST",
                "--input",
                payload_file,
            )
        else:
            gh(
                "api",
                f"repos/{args.repo}/issues/{issue['number']}",
                "--method",
                "PATCH",
                "--input",
                payload_file,
            )
    finally:
        Path(payload_file).unlink(missing_ok=True)

    print(rel(args.problem_set))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
