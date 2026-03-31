# `state`

## Scope

This module root defines the state-first architecture slice.

It is intentionally narrow:
- canonical state service operations: `get_state`, `hydrate_state`
- deterministic Git facts from `gix`
- semantic enrichment from `sem`
- ACP as structured transport only
- Marimo as default operational host binding plus registry, hydration, and view consumer
- `uv` as runtime environment substrate
- `just` as parity operator verb layer
- kernel packet review for the architecture slice

It does not attempt:
- repo write workflows
- generic Git capability shells
- full ACP implementation
- full Marimo implementation

## Canonical Surface Names

- `state.service.get`
- `state.service.hydrate`
- `state.interface.git.gix`
- `state.interface.semantic.sem`
- `state.transport.acp`
- `state.registry.marimo`
- `state.snapshot.unified`
- `controller.state.hydrate`
- `validator.state.schema`
- `generator.state.workflow_dag`
- `generator.state.dependency_order`
- `generator.state.interop_matrix`
- `packet.state.architecture`

## Artifact Set

- `control/modules/state/module.root.v1.json`
- `control/modules/state/inventory.v1.json`
- `control/modules/state/namespace.contract.v1.json`
- `control/modules/state/workflow_dag.v1.md`
- `control/modules/state/dependency_order.v1.json`
- `control/modules/state/interop_matrix.v1.json`
- `control/modules/state/migration.plan.v1.md`
- `control/modules/state/structure.v1.md`

## Naming Rule

- physical root remains domain-first: `control/modules/state`
- semantic ids remain class-first and qualified
- ACP is transport only
- Marimo is the default host binding operationally, not semantic authority
- `uv` remains the environment substrate, not semantic authority
- `just` remains the operator verb layer, not semantic authority
- state service semantics are primary; Git adapter/runtime details remain downstream
