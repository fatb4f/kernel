#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from jsonargparse import ArgumentParser

from run_problem_set_surface import DEFAULT_PROBLEM_SET, run


def build_parser() -> ArgumentParser:
    parser = ArgumentParser(description="Admit and render a normalized problem_set surface.")
    parser.add_argument("problem_set", nargs="?", type=Path, default=DEFAULT_PROBLEM_SET)
    parser.add_argument("--run-id", default="", help="Optional explicit run identifier")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = run(Path(args.problem_set), str(args.run_id))
    print(result["rendered_doc"])
    print(result["rendered_summary"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
