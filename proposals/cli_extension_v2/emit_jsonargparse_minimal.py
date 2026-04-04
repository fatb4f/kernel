#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
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
    commands = [o for o in objects.values() if o.attributes.get("cli_role") == "command_surface"]
    if len(commands) != 1:
        raise TransformError(
            f"expected exactly one command_surface object for minimal jsonargparse slice, found {len(commands)}"
        )
    return commands[0]


def collect_related_objects(
    command: CliObject, objects: dict[str, CliObject]
) -> tuple[list[CliObject], list[CliObject], list[CliObject], list[CliObject]]:
    options: list[CliObject] = []
    positionals: list[CliObject] = []
    envs: list[CliObject] = []
    others: list[CliObject] = []
    for obj in objects.values():
        role = obj.attributes.get("cli_role")
        if role == "parameter_surface" and obj.attributes.get("command_ref") == command.ref:
            if obj.attributes.get("parameter_kind") == "positional":
                positionals.append(obj)
            else:
                options.append(obj)
        elif role == "environment_binding":
            envs.append(obj)
        elif role in {"output_contract", "verification_expectation", "usage_example"}:
            others.append(obj)
    return options, positionals, envs, others


def cli_name(command: CliObject) -> str:
    command_path = command.attributes.get("command_path")
    if not isinstance(command_path, list) or not command_path:
        raise TransformError("command_surface.command_path must be a non-empty array")
    return "-".join(str(part) for part in command_path)


def preferred_formats(objects: list[CliObject]) -> list[str]:
    for obj in objects:
        if obj.attributes.get("cli_role") == "output_contract":
            formats = obj.attributes.get("preferred_formats")
            if isinstance(formats, list) and formats:
                return [str(x) for x in formats]
    return ["json"]


def env_binding_name(envs: list[CliObject]) -> str | None:
    if not envs:
        return None
    return str(envs[0].attributes.get("env_name"))


def render_parser_py(command: CliObject, options: list[CliObject], envs: list[CliObject], others: list[CliObject]) -> str:
    name = cli_name(command)
    description = command.summary
    env_name = env_binding_name(envs)
    formats = preferred_formats(others)
    default_format = formats[0]
    format_choices = ", ".join(repr(x) for x in formats)

    option_block: list[str] = []
    for option in options:
        attrs = option.attributes
        long_flag = attrs.get("long_flag")
        if not long_flag:
            raise TransformError(f"{option.ref} missing long_flag")
        arg_name = long_flag.lstrip("-").replace("-", "_")
        option_block.append(
            f"    parser.add_argument({long_flag!r}, dest={arg_name!r}, choices=[{format_choices}], default={default_format!r})"
        )

    env_prefix = ""
    default_env = "False"
    if env_name:
        env_prefix = env_name.removesuffix("_PROFILE")
        default_env = "True"

    lines = [
        "from __future__ import annotations",
        "",
        "import json",
        "import os",
        "from typing import Any",
        "",
        "from jsonargparse import ArgumentParser",
        "",
        "",
        f"def build_parser() -> ArgumentParser:",
        f"    parser = ArgumentParser(prog={name!r}, description={description!r}, env_prefix={env_prefix!r}, default_env={default_env})",
    ]
    lines.extend(option_block)
    lines.extend(
        [
            "    return parser",
            "",
            "",
            "def render_output(namespace: Any) -> str:",
            "    data = {",
            "        'status': 'ok',",
            "        'kind': 'control_plane_inspect',",
            "        'format': getattr(namespace, 'format', None) or 'json',",
        ]
    )
    if env_name:
        lines.extend(
            [
                f"        'profile_env_var': {env_name!r},",
                f"        'profile': os.environ.get({env_name!r}),",
            ]
        )
    lines.extend(
        [
            "    }",
            "    fmt = data['format']",
            "    if fmt == 'yaml':",
            "        return '\\n'.join(f\"{key}: {value}\" for key, value in data.items()) + '\\n'",
            "    return json.dumps(data, separators=(',', ':')) + '\\n'",
            "",
            "",
            "def main(argv: list[str] | None = None) -> int:",
            "    parser = build_parser()",
            "    args = parser.parse_args(argv)",
            "    print(render_output(args), end='')",
            "    return 0",
            "",
            "",
            "if __name__ == '__main__':",
            "    raise SystemExit(main())",
        ]
    )
    return "\n".join(lines) + "\n"


def render_pytest_suite(command: CliObject) -> str:
    name = cli_name(command)
    return (
        "from __future__ import annotations\n"
        "\n"
        "import subprocess\n"
        "import sys\n"
        "from pathlib import Path\n"
        "\n"
        "\n"
        "ROOT = Path(__file__).resolve().parent\n"
        "\n"
        "\n"
        "def run(*args: str):\n"
        "    return subprocess.run(\n"
        "        [sys.executable, str(ROOT / 'parser.py'), *args],\n"
        "        cwd=ROOT,\n"
        "        text=True,\n"
        "        capture_output=True,\n"
        "        check=False,\n"
        "    )\n"
        "\n"
        "\n"
        "def test_help_path():\n"
        "    result = run('--help')\n"
        "    assert result.returncode == 0\n"
        f"    assert {name!r} in result.stdout\n"
        "\n"
        "\n"
        "def test_success_path_json():\n"
        "    result = run('--format', 'json')\n"
        "    assert result.returncode == 0\n"
        "    assert '\"kind\":\"control_plane_inspect\"' in result.stdout\n"
        "\n"
        "\n"
        "def test_invalid_value_path():\n"
        "    result = run('--format', 'toml')\n"
        "    assert result.returncode != 0\n"
    )


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def check_python_syntax(path: Path) -> dict[str, Any]:
    result = subprocess.run(
        [sys.executable, "-m", "py_compile", str(path)],
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "command": f"{sys.executable} -m py_compile",
        "path": str(path),
        "ok": result.returncode == 0,
        "stderr": result.stderr.strip(),
    }


def detect_jsonargparse() -> dict[str, Any]:
    spec = importlib.util.find_spec("jsonargparse")
    uv_available = shutil.which("uv") is not None
    if spec is not None:
        return {
            "available": True,
            "module": "jsonargparse",
            "execution_mode": "current_python_environment",
            "status": "ready",
        }
    if uv_available:
        return {
            "available": True,
            "module": "jsonargparse",
            "execution_mode": "uv_ephemeral_runtime",
            "status": "ready_via_uv",
        }
    return {
        "available": False,
        "module": "jsonargparse",
        "execution_mode": "unavailable",
        "status": "unavailable_in_environment",
    }


def run_pytest(output_root: Path) -> dict[str, Any]:
    detection = detect_jsonargparse()
    if not detection["available"]:
        return {
            "available": False,
            "status": "unavailable_in_environment",
            "command": "uv run --with jsonargparse --with pytest python -m pytest -p no:cacheprovider -q test_control_plane_inspect.py",
        }
    result = subprocess.run(
        ["uv", "run", "--with", "jsonargparse", "--with", "pytest", "python", "-m", "pytest", "-p", "no:cacheprovider", "-q", "test_control_plane_inspect.py"],
        cwd=output_root,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "available": True,
        "status": "ok" if result.returncode == 0 else "failed",
        "command": "uv run --with jsonargparse --with pytest python -m pytest -p no:cacheprovider -q test_control_plane_inspect.py",
        "execution_mode": "uv_ephemeral_runtime",
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def emit_manifest(project_root: Path, emitted: list[dict[str, Any]]) -> Path:
    path = project_root / "realization_manifest.jsonargparse_minimal.json"
    manifest = {
        "document_type": "realization_manifest",
        "manifest_id": "jsonargparse_minimal_first_slice",
        "projection_kind": "codegen_projection",
        "emitted": emitted,
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def emit_report(
    project_root: Path,
    model_path: Path,
    contract_path: Path,
    parser_syntax: dict[str, Any],
    pytest_syntax: dict[str, Any],
    jsonargparse_status: dict[str, Any],
    pytest_result: dict[str, Any],
) -> Path:
    path = project_root / "realization_report.jsonargparse_minimal.json"
    report = {
        "document_type": "realization_report",
        "status": "source_surfaces_emitted",
        "canonical_model_path": str(model_path),
        "target_contract_path": str(contract_path),
        "lossy_mappings": [
            "command_path is flattened into one root parser prog for the minimal jsonargparse slice",
            "output_contract influences render_output behavior instead of becoming a first-class parser schema",
            "verification expectation is emitted as pytest source rather than enforced inside parser configuration",
        ],
        "checks": {
            "parser_python_syntax": parser_syntax,
            "pytest_source_python_syntax": pytest_syntax,
            "downstream_jsonargparse_runtime": jsonargparse_status,
            "downstream_pytest": pytest_result,
        },
    }
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="emit-jsonargparse-minimal",
        description="Emit the first jsonargparse minimal source surfaces from the CLI v2 semantic example.",
    )
    parser.add_argument("--model", default="canonical_semantic_model.cli.example.json")
    parser.add_argument("--contract", default="jsonargparse_target_contract.minimal.v1.json")
    parser.add_argument("--output-root", default="realized/jsonargparse_minimal/control_plane_inspect")
    parser.add_argument("--check-only", action="store_true")
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
        options, _positionals, envs, others = collect_related_objects(command, objects)

        parser_py = render_parser_py(command, options, envs, others)
        pytest_py = render_pytest_suite(command)

        if args.check_only:
            print(
                json.dumps(
                    {
                        "status": "ok",
                        "target_contract_id": contract["target_contract_id"],
                        "command_ref": command.ref,
                        "emittable_files": ["parser.py", "test_control_plane_inspect.py"],
                    },
                    indent=2,
                )
            )
            return 0

        parser_path = output_root / "parser.py"
        pytest_path = output_root / "test_control_plane_inspect.py"
        write_file(parser_path, parser_py)
        write_file(pytest_path, pytest_py)

        emitted = [
            {
                "surface_id": "jsonargparse_parser_source",
                "repo_path": "parser.py",
                "output_path": str(parser_path),
            },
            {
                "surface_id": "pytest_verification_source",
                "repo_path": "test_control_plane_inspect.py",
                "output_path": str(pytest_path),
            },
        ]
        parser_syntax = check_python_syntax(parser_path)
        pytest_syntax = check_python_syntax(pytest_path)
        jsonargparse_status = detect_jsonargparse()
        pytest_result = run_pytest(output_root)
        manifest_path = emit_manifest(output_root, emitted)
        report_path = emit_report(
            output_root,
            model_path,
            contract_path,
            parser_syntax,
            pytest_syntax,
            jsonargparse_status,
            pytest_result,
        )
        print(
            json.dumps(
                {
                    "status": "success",
                    "output_root": str(output_root),
                    "manifest": str(manifest_path),
                    "report": str(report_path),
                    "downstream_pytest": pytest_result["status"],
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
