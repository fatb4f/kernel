# Repo Factoring Migration Map v1

## Purpose

This map turns the live repo split into concrete file-level migration and alignment actions.

Scope:

- `fatb4f/kernel` as control representation
- `fatb4f/dotfiles/chezmoi/dot_config/codex` as operational substrate

## Kernel Ownership

The following kernel paths are already the correct home for semantic and contract authority:

- `control/modules/state/module.root.v1.json`
- `control/modules/state/inventory.v1.json`
- `control/modules/state/namespace.contract.v1.json`
- `control/modules/state/workflow_dag.v1.md`
- `control/modules/state/dependency_order.v1.json`
- `control/modules/state/interop_matrix.v1.json`
- `control/modules/state/migration.plan.v1.md`
- `control/modules/state/structure.v1.md`
- `control/runtime/runtime_surface_factoring.v1.md`
- `schemas/control/runtime.binding.v1.schema.json`
- `schemas/control/state.v1.schema.json`
- `schemas/control/session.v1.schema.json`
- `schemas/control/output.v1.schema.json`

## Kernel File Actions

| Path | Current role | Action | Target outcome |
| --- | --- | --- | --- |
| `control/modules/state/structure.v1.md` | state-slice scope note | continue revising | make Marimo-first operationally explicit without moving runtime mechanics into kernel |
| `control/modules/state/namespace.contract.v1.json` | target-state contract | continue revising | treat `marimo`, `uv`, and `just` as asymmetric bindings under the state plane |
| `control/modules/state/migration.plan.v1.md` | migration intent | continue revising | keep runtime realization steps pointed at Codex artifacts in `dotfiles` |
| `control/modules/state/workflow_dag.v1.md` | north-star workflow | amend | show direct local Marimo host path first, ACP only for boundary crossings |
| `control/modules/state/dependency_order.v1.json` | implementation ordering | amend | insert runtime binding family ahead of ACP-specific realization work |
| `control/modules/state/interop_matrix.v1.json` | boundary map | amend | separate host binding, runtime substrate, operator verbs, and transport |
| `control/runtime/runtime_surface_factoring.v1.md` | runtime factoring contract | retain and extend | make this the top-level statement of kernel vs Codex-in-dotfiles ownership |
| `schemas/control/runtime.binding.v1.schema.json` | runtime binding schema | retain and extend | add room for host, substrate, transport, and encoding semantics only |
| `schemas/control/state.v1.schema.json` | state envelope schema | retain and extend | become the request/response truth for `get_state` and `hydrate_state` |
| `schemas/control/session.v1.schema.json` | session metadata schema | retain and extend | hold staleness, continuation, and provenance semantics |
| `schemas/control/output.v1.schema.json` | output encoding schema | retain and extend | define `json`, `ndjson`, and `jsonl` projection contracts |

## Kernel Follow-On Artifacts

These are the next bounded kernel additions:

- `control/modules/state/state.request_response_contract.v1.json`
- `control/modules/state/session.metadata.v1.json`
- `control/modules/state/output.encodings.v1.json`

These should remain thin semantic contracts.

## Codex Dependencies Consumed By Kernel

Kernel should continue to reference, but not absorb, the following runtime-basis artifacts from the Codex tree hosted in `dotfiles`:

- `../dotfiles/chezmoi/dot_config/codex/control/proposals/git_substrate_adapters_v1/control_realize_git_substrate_adapters_v1.py`
- `../dotfiles/chezmoi/dot_config/codex/control/proposals/git_substrate_adapters_v1/emit_gix_runtime.py`
- `../dotfiles/chezmoi/dot_config/codex/control/proposals/git_substrate_adapters_v1/emit_sem_runtime.py`
- `../dotfiles/chezmoi/dot_config/codex/control/proposals/git_substrate_adapters_v1/gix_runtime_contract.v1.json`
- `../dotfiles/chezmoi/dot_config/codex/control/proposals/git_substrate_adapters_v1/sem_runtime_contract.v1.json`
- `../dotfiles/chezmoi/dot_config/codex/control/runtime/runtime_surface_cleanup_plan.v1.md`

## Cross-Repo Rule

Kernel may define:

- what a host binding means
- what a session means
- what an output encoding means
- what transport modes mean

Kernel must not define:

- notebook layout
- launcher implementation
- session storage implementation
- runtime log persistence
- local transport plumbing
