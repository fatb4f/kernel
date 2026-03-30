# `state` Migration Plan

## Purpose

This document captures migration intent for the state-first architecture slice.

It is separate from:
- `module.root.v1.json`
- `inventory.v1.json`
- `namespace.contract.v1.json`

## Planned Alignment

| Source surface | Current basis | Target surface | Action | Status |
| --- | --- | --- | --- | --- |
| unified Git runtime aggregation | `../codex_home/.../control_realize_git_substrate_adapters_v1.py` | `state.snapshot.unified` | reuse as substrate basis until state.v1 wrapper exists | planned |
| deterministic Git facts | `../codex_home/.../emit_gix_runtime.py` | `state.interface.git.gix` | bind into get_state wrapper later | planned |
| semantic enrichment | `../codex_home/.../emit_sem_runtime.py` | `state.interface.semantic.sem` | bind into hydrate_state wrapper later | planned |
| local operator surface | ad hoc shell/python entrypoints | `just state.get` / `just state.hydrate` | introduce as just-module entrypoint after state.v1 contract exists | planned |
| ACP transport | conceptual only | `state.transport.acp` | add request/response envelope once state.v1 is stable | planned |
| Marimo registry binding | conceptual only | `state.registry.marimo` | bind after ACP envelope and snapshot identity rules exist | planned |

## Constraints

- Do not let `hydrate_state` mutate the repo.
- Do not expose a generic Git shell.
- Do not let ACP become the model layer.
- Do not let Marimo depend on gix or sem implementation quirks.
