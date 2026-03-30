#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from jsonargparse import ArgumentParser

from run_chatgpt_packet_file import DEFAULT_PACKET_ROOT, REPO_ROOT, run, utc_run_id


def build_parser() -> ArgumentParser:
    parser = ArgumentParser(
        prog="run-chatgpt-packet-file",
        description="Dry-run packet runner for chatgpt-pipeline packet files.",
    )
    parser.add_argument(
        "packet",
        nargs="?",
        default=str(DEFAULT_PACKET_ROOT.relative_to(REPO_ROOT)),
        help="Packet root or machine/packet.definition.json path",
    )
    parser.add_argument("--run-id", default="")
    parser.add_argument("--execute", action="store_true", help="Reserved for future non-dry-run execution.")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    run_id = str(args.run_id or utc_run_id())
    result = run(str(args.packet), run_id, bool(args.execute))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
