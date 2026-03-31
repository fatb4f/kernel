# Runtime Surface Factoring v1

## Purpose

This document defines the control-plane factoring between `fatb4f/kernel` and the Codex tree hosted under `fatb4f/dotfiles/chezmoi/dot_config/codex` for the runtime surfaces currently expressed through `marimo`, `uv`, and `just`.

It is normative for role boundaries.
It is not a launcher implementation guide.

## Conclusion

`kernel` owns the meaning of runtime-control surfaces.
The Codex tree in `dotfiles` owns the operational substrate that realizes those surfaces.

The required split is:

- `kernel`:
  - semantic roles
  - service contracts
  - transport rules
  - structured output envelopes
  - session and staleness metadata
  - lineage and publication boundaries
- Codex in `dotfiles`:
  - runnable Marimo host/runtime behavior
  - `uv` environment and launcher behavior
  - `just` workflow verbs
  - MCP and ACP bindings
  - session persistence and streaming outputs
  - app-server and agent execution paths

## Runtime Role Model

These surfaces are intentionally asymmetric.

- `marimo`
  - role: default operational host/runtime shell
  - plane: host and view
  - owns no semantic contract authority
- `uv`
  - role: runtime environment and dependency substrate
  - plane: environment and launcher
  - owns no semantic contract authority
- `just`
  - role: stable operator verb layer
  - plane: named workflow entry and parity CLI surface
  - owns no semantic contract authority

## Contract Rule

`kernel` defines what these surfaces mean in the control plane:

- host identity
- transport mode
- envelope shape
- output encoding
- freshness and staleness semantics
- lineage back to kernel-owned contracts

The Codex tree in `dotfiles` defines how they run:

- process model
- notebook or app layout
- launcher wiring
- session persistence
- streaming behavior
- local or remote execution details

## State Plane Rule

The state plane remains semantically primary:

- `get_state`
- `hydrate_state`

Operational priority may still be Marimo-first.
That does not make Marimo the semantic authority.

The coherent split is:

- Marimo-first operationally
- state-contract-first semantically
- Python-first orchestrationally
- adapter-first only at substrate level

## Binding Rule

Kernel-side runtime binding contracts must be able to express at least:

- `host = marimo`
- `env_substrate = uv`
- `operator_entry = just`
- `transport = direct | mcp | acp`
- `encoding = json | ndjson | jsonl`

Those are control-plane meanings.
Their concrete implementations belong in the Codex tree in `dotfiles`.

## Lineage Rule

Every Codex runtime realization that claims kernel compatibility should be traceable to kernel contracts through explicit lineage such as:

- `generated_from`
- `validated_against`
- `emits`
- `transports_over`

## Non-Goals

This document does not:

- standardize notebook layout
- define `uv` project topology
- prescribe `justfile` structure
- define ACP transport internals
- define MCP server implementation details

Those remain implementation concerns in the Codex tree in `dotfiles`.
