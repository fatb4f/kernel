#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

from author_problem_set import build_issue_body, build_issue_title, load_json, rel, validate_instance, WORKFLOW_ROOT


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
    issues = gh_json(
        "issue",
        "list",
        "--repo",
        repo,
        "--state",
        "all",
        "--search",
        f"\"{problem_set_id}\" in:title",
        "--json",
        "number,title,url",
        "--limit",
        "100",
    )
    prefix = f": {problem_set_id} - "
    for issue in issues:
        if prefix in issue["title"]:
            return issue
    return None


def write_temp_body(body: str) -> str:
    fd, path = tempfile.mkstemp(prefix="problem-set-issue-", suffix=".md")
    with os.fdopen(fd, "w") as handle:
        handle.write(body)
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
    body_file = write_temp_body(body)
    try:
        if issue is None:
            cmd = [
                "issue",
                "create",
                "--repo",
                args.repo,
                "--title",
                title,
                "--body-file",
                body_file,
            ]
            for label in labels:
                cmd.extend(["--label", label])
            for assignee in assignees:
                cmd.extend(["--assignee", assignee])
            gh(*cmd)
        else:
            cmd = [
                "issue",
                "edit",
                str(issue["number"]),
                "--repo",
                args.repo,
                "--title",
                title,
                "--body-file",
                body_file,
            ]
            for label in labels:
                cmd.extend(["--add-label", label])
            gh(*cmd)
    finally:
        Path(body_file).unlink(missing_ok=True)

    print(rel(args.problem_set))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
