# Operational Status

Current baseline status for the kernel-spec-defined workflow:

- `OPEN`

## Why

The core closeout target is open. The repo now has executable slices across documentation, registries, policy, normalization, integrity, reason-code, and completion-obligation surfaces.

## What is true

- `reference-docs-executable-slice: G1-G6 evidence is committed`
- `boundary-family-registry-slice: registry render lane is committed`
- `policy-scope-surface-slice: policy/kernel source and policy-scope registry are committed`
- `drift-integrity-surface-slice: integrity registry and drift evidence are committed`
- `normalization-surface-slice: normalization registry and aggregated provenance are committed`
- `completion-obligations-surface-slice: invariants, output classes, implementation order, and completion conditions are committed`
- `local Jsonnet runtime is available via rsjsonnet`

## Decision basis

- `kernel core components are materially aligned across structure, contract, normalization, policy, rendering, control, and integrity surfaces`
- `all checklist items c1 through c11 are now materially aligned to committed evidence`
- `reason code family coverage is now materially linked to committed evidence across G1-G6`
- `closeout obligations are now materialized as an executable registry surface`
- `required local toolchains for JSON validation, CUE, and Jsonnet-backed rendering are available and policy-controlled`
- `no renderer, exporter, or compatibility shim is treated as authority`

## What is blocking status closure

None.

## Status rule

The core kernel operational status is open because the closeout manifest criteria are satisfied on record.

