#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class TransformError(Exception):
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
        raise TransformError(f"missing JSON artifact: {path}") from exc
    except json.JSONDecodeError as exc:
        raise TransformError(f"invalid JSON in {path}: {exc}") from exc


def require_keys(obj: dict[str, Any], keys: list[str], ctx: str) -> None:
    missing = [key for key in keys if key not in obj]
    if missing:
        raise TransformError(f"{ctx} missing required keys: {', '.join(missing)}")


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


def require_single_command(objects: dict[str, CliObject]) -> CliObject:
    commands = [
        obj
        for obj in objects.values()
        if obj.attributes.get("cli_role") == "command_surface"
    ]
    if len(commands) != 1:
        raise TransformError(
            f"expected exactly one command_surface object for minimal Bashly slice, found {len(commands)}"
        )
    return commands[0]


def collect_command_parameters(
    command: CliObject, objects: dict[str, CliObject]
) -> tuple[list[CliObject], list[CliObject], list[CliObject], list[CliObject]]:
    args: list[CliObject] = []
    flags: list[CliObject] = []
    envs: list[CliObject] = []
    other: list[CliObject] = []
    for obj in objects.values():
        role = obj.attributes.get("cli_role")
        if role == "parameter_surface" and obj.attributes.get("command_ref") == command.ref:
            kind = obj.attributes.get("parameter_kind")
            if kind == "positional":
                args.append(obj)
            elif kind in {"option", "flag"}:
                flags.append(obj)
            else:
                other.append(obj)
        elif role == "environment_binding":
            envs.append(obj)
        elif role in {"output_contract", "usage_example", "verification_expectation"}:
            other.append(obj)
    return args, flags, envs, other


def shell_quote_yaml(value: str) -> str:
    if value == "" or any(ch in value for ch in ':#[]"\'\n{}[],&*!|>?%@`'):
        return json.dumps(value)
    return value


def render_bashly_yml(
    *,
    model_version: str,
    command: CliObject,
    args: list[CliObject],
    flags: list[CliObject],
) -> str:
    command_path = command.attributes.get("command_path")
    if not isinstance(command_path, list) or not command_path:
        raise TransformError("command_surface.command_path must be a non-empty array")

    lines: list[str] = [
        f"name: {'-'.join(str(part) for part in command_path)}",
        f"help: {shell_quote_yaml(command.summary)}",
        f"version: {model_version}",
    ]

    if args:
        lines.append("")
        lines.append("args:")
        for arg in args:
            attrs = arg.attributes
            name = attrs.get("name") or attrs.get("arg_name")
            if not name:
                raise TransformError(f"{arg.ref} missing positional arg name")
            lines.append(f"- name: {name}")
            if attrs.get("required") is True:
                lines.append("  required: true")
            help_text = attrs.get("help") or arg.summary
            if help_text:
                lines.append(f"  help: {shell_quote_yaml(str(help_text))}")

    if flags:
        lines.append("")
        lines.append("flags:")
        for flag in flags:
            attrs = flag.attributes
            long_flag = attrs.get("long_flag")
            if not long_flag:
                raise TransformError(f"{flag.ref} missing long_flag")
            lines.append(f"- long: {long_flag}")
            short_flag = attrs.get("short_flag")
            if short_flag:
                lines.append(f"  short: {short_flag}")
            if attrs.get("parameter_kind") == "option":
                arg_name = attrs.get("arg_name") or long_flag.lstrip("-")
                lines.append(f"  arg: {arg_name}")
            help_text = attrs.get("help") or flag.summary
            if help_text:
                lines.append(f"  help: {shell_quote_yaml(str(help_text))}")
            if attrs.get("required") is True:
                lines.append("  required: true")
            choices = attrs.get("choices")
            if isinstance(choices, list) and choices:
                lines.append("  allowed:")
                for choice in choices:
                    lines.append(f"  - {choice}")

    examples = synthesize_examples(command, flags)
    if examples:
        lines.append("")
        lines.append("examples:")
        for example in examples:
            lines.append(f"- {example}")

    return "\n".join(lines) + "\n"


def synthesize_examples(command: CliObject, flags: list[CliObject]) -> list[str]:
    command_path = command.attributes["command_path"]
    cli_name = "-".join(str(part) for part in command_path)
    format_flag = None
    for flag in flags:
        if flag.attributes.get("long_flag") == "--format":
            format_flag = flag
            break
    if format_flag:
        choices = format_flag.attributes.get("choices")
        if isinstance(choices, list) and choices:
            return [f"{cli_name} --format {choice}" for choice in choices]
        return [f"{cli_name} --format json"]
    return [cli_name]


def render_root_partial(command: CliObject) -> str:
    handler_id = command.attributes.get("handler_id", "root")
    return (
        "# Generated from the canonical CLI model.\n"
        f"# handler_id: {handler_id}\n"
        "# This minimal Bashly slice intentionally omits env bindings and keeps\n"
        "# behavior in the root partial so regeneration remains safe.\n"
        'format="${args[--format]:-json}"\n'
        "\n"
        'case "$format" in\n'
        "  json)\n"
        "    cat <<'EOF'\n"
        '{\"status\":\"ok\",\"kind\":\"control_plane_inspect\"}\n'
        "EOF\n"
        "    ;;\n"
        "  yaml)\n"
        "    cat <<'EOF'\n"
        "status: ok\n"
        "kind: control_plane_inspect\n"
        "EOF\n"
        "    ;;\n"
        "  *)\n"
        '    echo "unsupported format: $format" >&2\n'
        "    exit 1\n"
        "    ;;\n"
        "esac\n"
    )


def cli_name_for_command(command: CliObject) -> str:
    command_path = command.attributes.get("command_path")
    if not isinstance(command_path, list) or not command_path:
        raise TransformError("command_surface.command_path must be a non-empty array")
    return "-".join(str(part) for part in command_path)


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def check_shell_syntax(root_command_path: Path) -> dict[str, Any]:
    result = subprocess.run(
        ["bash", "-n", str(root_command_path)],
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "command": "bash -n",
        "path": str(root_command_path),
        "ok": result.returncode == 0,
        "stderr": result.stderr.strip(),
    }


def resolve_bashly_command() -> list[str] | None:
    candidates: list[Path] = []
    path_env = os.environ.get("PATH", "")
    for entry in path_env.split(":"):
        if entry:
            candidates.append(Path(entry) / "bashly")
    candidates.append(Path.home() / ".local" / "share" / "gem" / "ruby" / "3.4.0" / "bin" / "bashly")

    for candidate in candidates:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return [str(candidate)]
    return None


def detect_bashly() -> dict[str, Any]:
    command = resolve_bashly_command()
    if command is None:
        return {
            "available": False,
            "command": "bashly generate",
            "status": "unavailable_in_environment",
        }
    return {
        "available": True,
        "command": f"{command[0]} generate",
        "status": "ready",
    }


def run_bashly_generate(project_root: Path) -> dict[str, Any]:
    command = resolve_bashly_command()
    if command is None:
        return {
            "available": False,
            "status": "unavailable_in_environment",
            "command": "bashly generate",
        }
    result = subprocess.run(
        [*command, "generate"],
        cwd=project_root,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "available": True,
        "status": "ok" if result.returncode == 0 else "failed",
        "command": f"{command[0]} generate",
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def emit_manifest(project_root: Path, emitted: list[dict[str, Any]]) -> Path:
    path = project_root / "realization_manifest.bashly_minimal.json"
    manifest = {
        "document_type": "realization_manifest",
        "manifest_id": "bashly_minimal_first_slice",
        "projection_kind": "config_projection",
        "emitted": emitted,
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def emit_report(
    project_root: Path,
    model_path: Path,
    contract_path: Path,
    syntax_check: dict[str, Any],
    bashly_status: dict[str, Any],
) -> Path:
    path = project_root / "realization_report.bashly_minimal.json"
    report = {
        "document_type": "realization_report",
        "status": "source_surfaces_emitted",
        "canonical_model_path": str(model_path),
        "target_contract_path": str(contract_path),
        "lossy_mappings": [
            "command_path is flattened into one root CLI name for the minimal Bashly slice",
            "environment_binding is intentionally omitted from the first Bashly slice",
            "output_contract is realized in root partial behavior rather than Bashly config"
        ],
        "checks": {
            "root_partial_shell_syntax": syntax_check,
            "downstream_bashly_generate": bashly_status,
        },
    }
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-bashly-minimal",
        description="Emit the first Bashly minimal source surfaces from the CLI v2 semantic example.",
    )
    parser.add_argument(
        "--model",
        default="canonical_semantic_model.cli.example.json",
        help="Path to the canonical semantic model JSON.",
    )
    parser.add_argument(
        "--contract",
        default="bashly_target_contract.minimal.v1.json",
        help="Path to the Bashly minimal target contract JSON.",
    )
    parser.add_argument(
        "--output-root",
        default="realized/bashly_minimal/control_plane_inspect",
        help="Output root for the emitted Bashly project source tree.",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate transform inputs without writing files.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    cwd = Path.cwd()
    model_path = (cwd / args.model).resolve() if not Path(args.model).is_absolute() else Path(args.model)
    contract_path = (cwd / args.contract).resolve() if not Path(args.contract).is_absolute() else Path(args.contract)
    output_root = (cwd / args.output_root).resolve() if not Path(args.output_root).is_absolute() else Path(args.output_root)

    try:
        model = load_json(model_path)
        contract = load_json(contract_path)
        require_keys(contract, ["target_contract_id", "required_source_surfaces"], "target_contract")

        objects = normalize_objects(model)
        command = require_single_command(objects)
        args_surfaces, flags, _envs, _other = collect_command_parameters(command, objects)

        bashly_yml = render_bashly_yml(
            model_version=str(model.get("version", "0.1.0")),
            command=command,
            args=args_surfaces,
            flags=flags,
        )
        root_partial = render_root_partial(command)

        if args.check_only:
            print(
                json.dumps(
                    {
                        "status": "ok",
                        "target_contract_id": contract["target_contract_id"],
                        "command_ref": command.ref,
                        "emittable_files": ["src/bashly.yml", "src/root_command.sh"],
                    },
                    indent=2,
                )
            )
            return 0

        bashly_yml_path = output_root / "src" / "bashly.yml"
        root_partial_path = output_root / "src" / "root_command.sh"
        write_file(bashly_yml_path, bashly_yml)
        write_file(root_partial_path, root_partial)

        emitted = [
            {
                "surface_id": "bashly_cli_source",
                "repo_path": "src/bashly.yml",
                "output_path": str(bashly_yml_path),
            },
            {
                "surface_id": "bashly_root_partial",
                "repo_path": "src/root_command.sh",
                "output_path": str(root_partial_path),
            },
        ]
        syntax_check = check_shell_syntax(root_partial_path)
        bashly_status = detect_bashly()
        generate_result = run_bashly_generate(output_root)
        generated_script_path = output_root / cli_name_for_command(command)
        if generate_result.get("status") == "ok" and generated_script_path.exists():
            emitted.append(
                {
                    "surface_id": "bashly_generated_script",
                    "repo_path": generated_script_path.name,
                    "output_path": str(generated_script_path),
                }
            )
        manifest_path = emit_manifest(output_root, emitted)
        report_path = emit_report(
            output_root,
            model_path,
            contract_path,
            syntax_check,
            {
                "discovery": bashly_status,
                "generate": generate_result,
            },
        )

        print(
            json.dumps(
                {
                    "status": "success",
                    "output_root": str(output_root),
                    "manifest": str(manifest_path),
                    "report": str(report_path),
                    "downstream_bashly_generate": generate_result["status"],
                },
                indent=2,
            )
        )
        return 0
    except TransformError as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
