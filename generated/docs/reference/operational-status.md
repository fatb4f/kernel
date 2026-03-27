# Operational Status

Current baseline status for the kernel-spec-defined workflow:

- `BLOCKED`

## Why

The core closeout target remains blocked, but the repo now has multiple executable slices across documentation, registries, policy, normalization, and integrity surfaces.

## What is true

- `reference-docs-executable-slice: G1-G6 evidence is committed`
- `boundary-family-registry-slice: registry render lane is committed`
- `policy-scope-surface-slice: policy/kernel source and policy-scope registry are committed`
- `drift-integrity-surface-slice: integrity registry and drift evidence are committed`
- `normalization-surface-slice: normalization registry and aggregated provenance are committed`
- `local Jsonnet runtime is available via rsjsonnet`

## Decision basis

- `kernel core components are materially aligned across structure, contract, normalization, policy, rendering, control, and integrity surfaces`
- `checklist item c10 remains open, so completion criteria are not yet fully satisfied`
- `reason code family coverage is now materially linked to committed evidence across G1-G6`
- `closeout obligation closure still needs explicit finalization`
- `required local toolchains for JSON validation, CUE, and Jsonnet-backed rendering are available and policy-controlled`
- `no renderer, exporter, or compatibility shim is treated as authority`

## What is blocking status closure

- `completion_obligations_not_fully_closed`

## Status rule

The core kernel operational status remains not closed until the closeout manifest criteria are satisfied across the broader kernel surface.

