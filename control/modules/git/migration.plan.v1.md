# `git` Migration Plan

## Purpose

This document captures migration intent for the `control/modules/git` domain.

It is separate from:
- `module.root.v1.json`: module identity and composition
- `inventory.v1.json`: present-state facts
- `namespace.contract.v1.json`: target-state requirements

## Planned Alignment

| Source surface | Current path | Target surface | Action | Status |
| --- | --- | --- | --- | --- |
| packet admission entrypoint | `scripts/run_chatgpt_packet_file.py` | `packet.git.admit` | keep current path until a namespaced module implementation exists | planned |
| packet realization entrypoint | `scripts/realize_git_substrate_packet.py` | `packet.git.realize` | keep current path until a namespaced module implementation exists | planned |
| packet closeout entrypoint | `scripts/close_git_substrate_packet.py` | `packet.git.closeout` | keep current path until a namespaced module implementation exists | planned |
| gix projection backend | `../codex_home/.../emit_gix_runtime.py` | `state.git.interface.gix` | retain as external basis until kernel owns a local projection backend | planned |
| sem projection backend | `../codex_home/.../emit_sem_runtime.py` | `state.git.interface.sem` | retain as external basis until kernel owns a local projection backend | planned |

## Constraints

- Do not move generated runtime state into authored module paths.
- Do not reclassify external proposal-basis code as owned kernel implementation.
- Do not fold migration intent back into schema-governed inventory or contract artifacts.
