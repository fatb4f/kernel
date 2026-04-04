#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ALLOWED_FAMILIES = {
    "shell_implementation",
    "python_implementation",
    "shell_verification",
    "python_verification",
}

ALLOWED_BACKENDS = {
    "bashly": "shell_implementation",
    "jsonargparse": "python_implementation",
    "bats": "shell_verification",
    "pytest": "python_verification",
}

ALLOWED_ARTIFACT_KINDS = {
    "config_projection",
    "codegen_input",
    "verification_projection",
}

PRIMARY_OPERATOR_SURFACE = "control_realize_cli_extension_v2.py"


class RealizationError(Exception):
    pass


@dataclass(frozen=True)
class CliObject:
    ref: str
    object_kind: str
    title: str
    summary: str
    attributes: dict[str, Any]


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RealizationError(f"missing JSON artifact: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RealizationError(f"invalid JSON in {path}: {exc}") from exc


def load_schema(path: Path) -> dict[str, Any]:
    return load_json(path)


def require_keys(obj: dict[str, Any], keys: list[str], ctx: str) -> None:
    missing = [key for key in keys if key not in obj]
    if missing:
        raise RealizationError(f"{ctx} missing required keys: {', '.join(missing)}")


def resolve_artifact_ref(cwd: Path, ref: str) -> Path:
    if not ref.startswith("artifact:"):
        raise RealizationError(f"unsupported authority ref: {ref}")
    return cwd / ref.removeprefix("artifact:")


def validate_payload(cwd: Path, payload: dict[str, Any]) -> tuple[dict[str, Any], set[str]]:
    require_keys(payload, ["authority_inputs", "realization_scope", "targets", "workflow"], "payload")

    authority_inputs = payload["authority_inputs"]
    require_keys(
        authority_inputs,
        ["canonical_model_ref", "constraint_ref", "profile_ref", "projection_manifest_ref"],
        "authority_inputs",
    )
    for key, ref in authority_inputs.items():
        path = resolve_artifact_ref(cwd, ref)
        if not path.exists():
            raise RealizationError(f"{key} does not resolve locally: {ref}")

    model = load_json(resolve_artifact_ref(cwd, authority_inputs["canonical_model_ref"]))
    object_refs = {str(obj["ref"]) for obj in model.get("objects", [])}

    scope = payload["realization_scope"]
    require_keys(scope, ["allowed_adapter_families", "allowed_backends"], "realization_scope")
    allowed_families = set(scope["allowed_adapter_families"])
    allowed_backends = set(scope["allowed_backends"])

    unknown_families = allowed_families - ALLOWED_FAMILIES
    if unknown_families:
        raise RealizationError(f"unknown adapter families: {sorted(unknown_families)}")
    unknown_backends = allowed_backends - set(ALLOWED_BACKENDS)
    if unknown_backends:
        raise RealizationError(f"unknown backends: {sorted(unknown_backends)}")

    seen_ids: set[str] = set()
    for target in payload["targets"]:
        require_keys(
            target,
            ["target_id", "backend", "adapter_family", "projection_role", "inputs", "artifact_kind", "repo_path"],
            "target",
        )
        target_id = str(target["target_id"])
        if target_id in seen_ids:
            raise RealizationError(f"duplicate target_id: {target_id}")
        seen_ids.add(target_id)
        backend = str(target["backend"])
        family = str(target["adapter_family"])
        if backend not in allowed_backends:
            raise RealizationError(f"target {target_id}: backend '{backend}' not enabled")
        if family not in allowed_families:
            raise RealizationError(f"target {target_id}: adapter_family '{family}' not enabled")
        if ALLOWED_BACKENDS[backend] != family:
            raise RealizationError(
                f"target {target_id}: backend '{backend}' does not match adapter_family '{family}'"
            )
        artifact_kind = str(target["artifact_kind"])
        if artifact_kind not in ALLOWED_ARTIFACT_KINDS:
            raise RealizationError(f"target {target_id}: unsupported artifact_kind '{artifact_kind}'")
        inputs = [str(x) for x in target["inputs"]]
        if not inputs:
            raise RealizationError(f"target {target_id}: inputs must not be empty")
        missing_inputs = sorted(set(inputs) - object_refs)
        if missing_inputs:
            raise RealizationError(
                f"target {target_id}: unresolved semantic inputs: {', '.join(missing_inputs)}"
            )

    workflow = payload["workflow"]
    require_keys(workflow, ["command", "deterministic", "overwrite_policy", "manifest_update"], "workflow")
    if workflow["command"] != "control realize cli-extension-v2":
        raise RealizationError("workflow.command must be exactly 'control realize cli-extension-v2'")
    if workflow["deterministic"] is not True:
        raise RealizationError("workflow.deterministic must be true")

    return model, object_refs


def normalize_objects(model: dict[str, Any]) -> dict[str, CliObject]:
    objects: dict[str, CliObject] = {}
    for raw in model.get("objects", []):
        require_keys(raw, ["ref", "object_kind", "title", "summary", "attributes"], "object")
        ref = str(raw["ref"])
        objects[ref] = CliObject(
            ref=ref,
            object_kind=str(raw["object_kind"]),
            title=str(raw["title"]),
            summary=str(raw["summary"]),
            attributes=dict(raw["attributes"]),
        )
    return objects


def target_input_objects(target: dict[str, Any], objects: dict[str, CliObject]) -> list[CliObject]:
    return [objects[str(ref)] for ref in target["inputs"]]


def cli_name_from_objects(target_objects: list[CliObject]) -> str:
    for obj in target_objects:
        if obj.attributes.get("cli_role") == "command_surface":
            command_path = obj.attributes.get("command_path")
            if isinstance(command_path, list) and command_path:
                return "-".join(str(part) for part in command_path)
    raise RealizationError("unable to resolve command_surface for verification projection")


def preferred_formats_from_objects(target_objects: list[CliObject]) -> list[str]:
    for obj in target_objects:
        role = obj.attributes.get("cli_role")
        if role == "output_contract":
            formats = obj.attributes.get("preferred_formats")
            if isinstance(formats, list) and formats:
                return [str(x) for x in formats]
        if role == "parameter_surface" and obj.attributes.get("long_flag") == "--format":
            choices = obj.attributes.get("choices")
            if isinstance(choices, list) and choices:
                return [str(x) for x in choices]
    return ["json"]


def env_name_from_objects(target_objects: list[CliObject]) -> str | None:
    for obj in target_objects:
        if obj.attributes.get("cli_role") == "environment_binding":
            env_name = obj.attributes.get("env_name")
            if env_name:
                return str(env_name)
    return None


def run_child(cwd: Path, script_name: str, output_root: Path) -> dict[str, Any]:
    result = subprocess.run(
        [sys.executable, str(cwd / script_name), "--output-root", str(output_root)],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RealizationError(f"{script_name} failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def read_child_report(path: Path) -> dict[str, Any]:
    return load_json(path)


def validate_unified_document(document: dict[str, Any], schema: dict[str, Any], ctx: str) -> None:
    require_keys(document, list(schema.get("required", [])), ctx)
    properties = schema.get("properties", {})
    additional_allowed = bool(schema.get("additionalProperties", True))
    if not additional_allowed:
        extra = sorted(set(document) - set(properties))
        if extra:
            raise RealizationError(f"{ctx} has unexpected keys: {', '.join(extra)}")
    for key, prop in properties.items():
        if key not in document:
            continue
        value = document[key]
        if "const" in prop and value != prop["const"]:
            raise RealizationError(f"{ctx}.{key} must equal {prop['const']!r}")
        prop_type = prop.get("type")
        if prop_type == "string" and not isinstance(value, str):
            raise RealizationError(f"{ctx}.{key} must be a string")
        if prop_type == "boolean" and not isinstance(value, bool):
            raise RealizationError(f"{ctx}.{key} must be a boolean")
        if prop_type == "integer" and not isinstance(value, int):
            raise RealizationError(f"{ctx}.{key} must be an integer")
        if prop_type == "array":
            if not isinstance(value, list):
                raise RealizationError(f"{ctx}.{key} must be an array")
            item_schema = prop.get("items", {})
            if item_schema.get("type") == "object":
                for idx, item in enumerate(value):
                    if not isinstance(item, dict):
                        raise RealizationError(f"{ctx}.{key}[{idx}] must be an object")
                    validate_unified_document(item, item_schema, f"{ctx}.{key}[{idx}]")
            elif item_schema.get("type") == "string":
                for idx, item in enumerate(value):
                    if not isinstance(item, str):
                        raise RealizationError(f"{ctx}.{key}[{idx}] must be a string")
        if prop_type == "object":
            if not isinstance(value, dict):
                raise RealizationError(f"{ctx}.{key} must be an object")
            nested_required = prop.get("required", [])
            for nested_key in nested_required:
                if nested_key not in value:
                    raise RealizationError(f"{ctx}.{key} missing required key: {nested_key}")


def render_bats_suite(script_relpath: str, formats: list[str]) -> str:
    preferred = formats[0] if formats else "json"
    alt = formats[1] if len(formats) > 1 else None
    lines = [
        "#!/usr/bin/env bats",
        "",
        "setup() {",
        f"  SCRIPT=\"{script_relpath}\"",
        "}",
        "",
        "@test \"help path works\" {",
        "  run \"$SCRIPT\" --help",
        "  [ \"$status\" -eq 0 ]",
        "}",
        "",
        f"@test \"success path emits {preferred}\" {{",
        f"  run \"$SCRIPT\" --format {preferred}",
        "  [ \"$status\" -eq 0 ]",
        "  [[ \"$output\" == *'kind'* ]]",
        "}",
        "",
    ]
    if alt is not None:
        lines.extend(
            [
                f"@test \"alternate format emits {alt}\" {{",
                f"  run \"$SCRIPT\" --format {alt}",
                "  [ \"$status\" -eq 0 ]",
                "  [[ \"$output\" == *'kind'* ]]",
                "}",
                "",
            ]
        )
    lines.extend(
        [
            "@test \"invalid format fails\" {",
            "  run \"$SCRIPT\" --format toml",
            "  [ \"$status\" -ne 0 ]",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def render_pytest_suite(
    parser_relpath: str,
    cli_name: str,
    formats: list[str],
    env_name: str | None,
) -> str:
    preferred = formats[0] if formats else "json"
    alt = formats[1] if len(formats) > 1 else None
    lines = [
        "from __future__ import annotations",
        "",
        "import os",
        "import subprocess",
        "import sys",
        "from pathlib import Path",
        "",
        "",
        "ROOT = Path(__file__).resolve().parent",
        f"PARSER = ROOT / {parser_relpath!r}",
        "",
        "",
        "def run(*args: str, env: dict[str, str] | None = None):",
        "    merged_env = os.environ.copy()",
        "    if env is not None:",
        "        merged_env.update(env)",
        "    return subprocess.run(",
        "        [sys.executable, str(PARSER), *args],",
        "        cwd=ROOT,",
        "        text=True,",
        "        capture_output=True,",
        "        check=False,",
        "        env=merged_env,",
        "    )",
        "",
        "",
        "def test_help_path():",
        "    result = run('--help')",
        "    assert result.returncode == 0",
        f"    assert {cli_name!r} in result.stdout",
        "",
        "",
        f"def test_success_path_{preferred}():",
        f"    result = run('--format', '{preferred}')",
        "    assert result.returncode == 0",
        "    assert 'kind' in result.stdout",
        "",
        "",
    ]
    if alt is not None:
        lines.extend(
            [
                f"def test_success_path_{alt}():",
                f"    result = run('--format', '{alt}')",
                "    assert result.returncode == 0",
                "    assert 'kind' in result.stdout",
                "",
                "",
            ]
        )
    if env_name is not None:
        lines.extend(
            [
                "def test_environment_binding_round_trips():",
                f"    result = run('--format', '{preferred}', env={{'{env_name}': 'dev'}})",
                "    assert result.returncode == 0",
                "    assert 'dev' in result.stdout",
                "",
                "",
            ]
        )
    lines.extend(
        [
            "def test_invalid_value_path():",
            "    result = run('--format', 'toml')",
            "    assert result.returncode != 0",
            "",
        ]
    )
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def copy_file(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)


def build_unified_manifest(root: Path, payload: dict[str, Any], emitted: list[dict[str, Any]]) -> Path:
    path = root / "build" / "realization_manifest.json"
    manifest = {
        "document_type": "realization_manifest",
        "schema_version": "v2",
        "workflow_command": payload["workflow"]["command"],
        "deterministic": payload["workflow"]["deterministic"],
        "primary_operator_surface": PRIMARY_OPERATOR_SURFACE,
        "targets": emitted,
    }
    validate_unified_document(
        manifest,
        load_schema(Path(__file__).resolve().parent / "unified_realization_manifest.v2.schema.json"),
        "realization_manifest",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def build_unified_report(
    root: Path,
    payload_path: Path,
    emitted: list[dict[str, Any]],
    backend_reports: dict[str, Any],
) -> Path:
    path = root / "build" / "realization_report.json"
    report = {
        "document_type": "realization_report",
        "schema_version": "v2",
        "status": "success",
        "payload_path": str(payload_path),
        "primary_operator_surface": PRIMARY_OPERATOR_SURFACE,
        "realized_count": len(emitted),
        "targets": emitted,
        "backend_reports": backend_reports,
    }
    validate_unified_document(
        report,
        load_schema(Path(__file__).resolve().parent / "unified_realization_report.v2.schema.json"),
        "realization_report",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="control realize cli-extension-v2",
        description="Unified realization runner for the Bashly and jsonargparse bounded slices.",
    )
    parser.add_argument("--payload", default="realization_payload.v2.json")
    parser.add_argument("--root", default=".")
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    cwd = Path(__file__).resolve().parent
    payload_path = (cwd / args.payload).resolve() if not Path(args.payload).is_absolute() else Path(args.payload)
    root = Path(args.root).resolve()

    try:
        payload = load_json(payload_path)
        model, _object_refs = validate_payload(cwd, payload)
        objects = normalize_objects(model)

        if args.check_only:
            print(json.dumps({"status": "ok", "validated_targets": len(payload["targets"])}, indent=2))
            return 0

        bashly_project_root = root / "build" / "bashly" / "control_plane_inspect"
        jsonargparse_project_root = root / "build" / "python" / "control_plane_inspect"

        bashly_run = run_child(cwd, "emit_bashly_minimal.py", bashly_project_root)
        jsonargparse_run = run_child(cwd, "emit_jsonargparse_minimal.py", jsonargparse_project_root)

        bashly_report = read_child_report(Path(bashly_run["report"]))
        jsonargparse_report = read_child_report(Path(jsonargparse_run["report"]))

        emitted: list[dict[str, Any]] = []
        for target in payload["targets"]:
            target_id = str(target["target_id"])
            backend = str(target["backend"])
            artifact_kind = str(target["artifact_kind"])
            repo_path = str(target["repo_path"])

            if backend == "bashly":
                actual = bashly_project_root / "src" / "bashly.yml"
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": artifact_kind,
                        "repo_path": repo_path,
                        "output_path": str(actual),
                        "source_project_root": str(bashly_project_root),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )
            elif backend == "jsonargparse":
                actual = jsonargparse_project_root / "parser.py"
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": artifact_kind,
                        "repo_path": repo_path,
                        "output_path": str(actual),
                        "source_project_root": str(jsonargparse_project_root),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )
            elif backend == "pytest":
                dest = root / repo_path
                verification_objects = target_input_objects(target, objects)
                implementation_objects = target_input_objects(payload["targets"][1], objects)
                env_name = env_name_from_objects(implementation_objects)
                formats = preferred_formats_from_objects(implementation_objects)
                parser_relpath = "../../python/control_plane_inspect/parser.py"
                write_text(
                    dest,
                    render_pytest_suite(
                        parser_relpath=parser_relpath,
                        cli_name=cli_name_from_objects(verification_objects + implementation_objects),
                        formats=formats,
                        env_name=env_name,
                    ),
                )
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": artifact_kind,
                        "repo_path": repo_path,
                        "output_path": str(dest),
                        "source_project_root": str(jsonargparse_project_root),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )
            elif backend == "bats":
                dest = root / repo_path
                script_relpath = "../../bashly/control_plane_inspect/control-plane-inspect"
                verification_objects = target_input_objects(target, objects)
                implementation_objects = target_input_objects(payload["targets"][0], objects)
                formats = preferred_formats_from_objects(implementation_objects)
                write_text(dest, render_bats_suite(script_relpath, formats))
                emitted.append(
                    {
                        "target_id": target_id,
                        "backend": backend,
                        "adapter_family": str(target["adapter_family"]),
                        "projection_role": str(target["projection_role"]),
                        "artifact_kind": artifact_kind,
                        "repo_path": repo_path,
                        "output_path": str(dest),
                        "source_project_root": str(bashly_project_root),
                        "semantic_inputs": [str(x) for x in target["inputs"]],
                        "generated_by": PRIMARY_OPERATOR_SURFACE,
                    }
                )

        manifest_path = build_unified_manifest(root, payload, emitted)
        report_path = build_unified_report(
            root,
            payload_path,
            emitted,
            {
                "bashly": bashly_report,
                "jsonargparse": jsonargparse_report,
            },
        )

        print(
            json.dumps(
                {
                    "status": "success",
                    "realized_targets": len(emitted),
                    "manifest": str(manifest_path),
                    "report": str(report_path),
                },
                indent=2,
            )
        )
        return 0
    except RealizationError as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
