from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class GitProjectionError(Exception):
    pass


@dataclass(frozen=True)
class GitObject:
    ref: str
    object_kind: str
    title: str
    summary: str
    attributes: dict[str, Any]


def current_codex_root() -> Path:
    override = os.environ.get("CODEX_REPOSITORY_ROOT")
    if override:
        return Path(override).expanduser().resolve()
    return Path(__file__).resolve().parents[3]


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise GitProjectionError(f"missing JSON artifact: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GitProjectionError(f"invalid JSON in {path}: {exc}") from exc


def require_keys(obj: dict[str, Any], keys: list[str], ctx: str) -> None:
    missing = [key for key in keys if key not in obj]
    if missing:
        raise GitProjectionError(f"{ctx} missing required keys: {', '.join(missing)}")


def normalize_objects(model: dict[str, Any]) -> dict[str, GitObject]:
    objects: dict[str, GitObject] = {}
    for raw in model.get("objects", []):
        require_keys(raw, ["ref", "object_kind", "title", "summary", "attributes"], "object")
        ref = str(raw["ref"])
        objects[ref] = GitObject(
            ref=ref,
            object_kind=str(raw["object_kind"]),
            title=str(raw["title"]),
            summary=str(raw["summary"]),
            attributes=dict(raw["attributes"]),
        )
    return objects


def parse_repository_ref(repo_ref: str) -> Path:
    if not repo_ref.startswith("repo:"):
        raise GitProjectionError(f"unsupported repository_ref: {repo_ref}")
    raw = repo_ref.removeprefix("repo:")
    if raw in {"self", "codex://self"}:
        return current_codex_root()
    path = Path(raw).expanduser()
    if path.exists():
        return path.resolve()
    if path.name == "codex_home":
        return current_codex_root()
    return path.resolve()


def git_run(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise GitProjectionError(f"git command failed ({' '.join(args)}): {result.stderr.strip()}")
    return result.stdout


def emit_repo_state(obj: GitObject) -> dict[str, Any]:
    repo = parse_repository_ref(str(obj.attributes["repository_ref"]))
    head = git_run(repo, "rev-parse", "HEAD").strip()
    branch = git_run(repo, "rev-parse", "--abbrev-ref", "HEAD").strip()
    status_lines = [line for line in git_run(repo, "status", "--porcelain").splitlines() if line.strip()]
    return {
        "document_type": "repo_state",
        "repository_path": str(repo),
        "head": head,
        "branch": branch,
        "clean": len(status_lines) == 0,
        "status_entries": status_lines,
        "state_kind": obj.attributes["state_kind"],
    }


def emit_diff_state(obj: GitObject) -> dict[str, Any]:
    repo = parse_repository_ref(str(obj.attributes["repository_ref"]))
    comparison_ref = str(obj.attributes["comparison_ref"])
    base_ref = git_run(repo, "merge-base", "HEAD", comparison_ref).strip()
    head = git_run(repo, "rev-parse", "HEAD").strip()
    raw_name_status = git_run(repo, "diff", "--name-status", f"{base_ref}..{head}")
    changed_files: list[dict[str, Any]] = []
    for line in raw_name_status.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            changed_files.append({"status": parts[0], "path": parts[-1]})
    raw_numstat = git_run(repo, "diff", "--numstat", f"{base_ref}..{head}")
    numstat: list[dict[str, Any]] = []
    for line in raw_numstat.splitlines():
        parts = line.split("\t")
        if len(parts) == 3:
            numstat.append({"added": parts[0], "deleted": parts[1], "path": parts[2]})
    return {
        "document_type": "diff_state",
        "repository_path": str(repo),
        "comparison_ref": comparison_ref,
        "comparison_base": base_ref,
        "head": head,
        "changed_files": changed_files,
        "file_count": len(changed_files),
        "numstat": numstat,
        "state_kind": obj.attributes["state_kind"],
    }


def emit_semantic_diff(semantic_obj: GitObject, review_obj: GitObject, diff_state: dict[str, Any]) -> dict[str, Any]:
    changed_files = diff_state["changed_files"]
    by_status: dict[str, int] = {}
    by_extension: dict[str, int] = {}
    for item in changed_files:
        status = str(item["status"])
        path = str(item["path"])
        by_status[status] = by_status.get(status, 0) + 1
        ext = Path(path).suffix or "<none>"
        by_extension[ext] = by_extension.get(ext, 0) + 1
    return {
        "document_type": "semantic_diff",
        "repository_path": str(parse_repository_ref(str(semantic_obj.attributes["repository_ref"]))),
        "upstream_diff_ref": semantic_obj.attributes["upstream_diff_ref"],
        "review_basis_rule": review_obj.attributes["basis_rule"],
        "change_summary": {
            "file_count": diff_state["file_count"],
            "by_status": by_status,
            "by_extension": by_extension,
        },
        "review_basis": {
            "requires_repo_state_and_diff_state": True,
            "comparison_ref": diff_state["comparison_ref"],
            "comparison_base": diff_state["comparison_base"],
        },
    }


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def command_exists(command: str) -> bool:
    result = subprocess.run(
        ["bash", "-lc", f"command -v {command} >/dev/null 2>&1"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def resolve_sem_binary() -> tuple[str | None, str]:
    explicit = os.environ.get("SEM_BIN")
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if path.exists() and path.is_file():
            return str(path), "env"
    if command_exists("sem"):
        return "sem", "path"
    local_workspace = os.environ.get("SEM_WORKSPACE_ROOT")
    if local_workspace:
        local_debug = Path(local_workspace).expanduser().resolve() / "crates" / "target" / "debug" / "sem"
        if local_debug.exists() and local_debug.is_file():
            return str(local_debug), "workspace_env"
    return None, "unavailable"


def resolve_maturin() -> tuple[str | None, str]:
    explicit = os.environ.get("MATURIN_BIN")
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if path.exists() and path.is_file():
            return str(path), "env"
    if command_exists("maturin"):
        return "maturin", "path"
    cargo_bin = Path.home() / ".cargo" / "bin" / "maturin"
    if cargo_bin.exists() and cargo_bin.is_file():
        return str(cargo_bin), "cargo_home"
    return None, "unavailable"


def parse_sem_output(stdout: str) -> dict[str, Any]:
    cleaned = stdout.strip()
    if not cleaned:
        return {
            "summary": {
                "fileCount": 0,
                "added": 0,
                "modified": 0,
                "deleted": 0,
                "moved": 0,
                "renamed": 0,
                "total": 0,
            },
            "changes": [],
        }
    ansi_free = cleaned.replace("\x1b[2m", "").replace("\x1b[0m", "")
    if ansi_free == "No changes detected.":
        return {
            "summary": {
                "fileCount": 0,
                "added": 0,
                "modified": 0,
                "deleted": 0,
                "moved": 0,
                "renamed": 0,
                "total": 0,
            },
            "changes": [],
        }
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise GitProjectionError(f"sem output was not valid JSON: {exc}") from exc


def build_review_basis(review_obj: GitObject, repo_obj: GitObject, diff_state: dict[str, Any]) -> dict[str, Any]:
    return {
        "document_type": "review_basis",
        "repository_ref": repo_obj.attributes["repository_ref"],
        "repo_state_ref": repo_obj.ref,
        "diff_state_ref": diff_state.get("source_ref", "object:codex_home_diff_state"),
        "requires_repo_state_and_diff_state": True,
        "basis_rule": review_obj.attributes["basis_rule"],
        "comparison_ref": diff_state["comparison_ref"],
        "comparison_base": diff_state["comparison_base"],
    }
