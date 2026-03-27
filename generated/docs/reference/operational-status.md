# Operational Status

Current baseline status for the kernel-spec-defined workflow:

- `BLOCKED`

## Why

The core closeout target remains blocked, but the Jsonnet runtime blocker is resolved and one bounded executable slice is now materialized.

## What is true

- `reference-docs-executable-slice: G1-G6 evidence is committed`
- `local Jsonnet runtime is available via rsjsonnet`

## Decision basis

- `all checklist_items marked done`
- `all kernel_core_components marked done`
- `completion_criteria satisfied`
- `evidence matches the full kernel.spec.json authority, state-flow, plane, contract, gate, and artifact model`
- `required toolchains for json-structure, json-schema, CUE, and Jsonnet are available and policy-controlled`
- `no renderer, exporter, or compatibility shim is treated as authority`

## What is blocking status closure

- `structures_core_not_fully_materialized`
- `schemas_exported_not_fully_materialized`
- `cue_policy_not_fully_materialized`
- `normalization_outputs_not_materialized_outside_first_slice`
- `admission_evidence_not_materialized_outside_first_slice`
- `render_evidence_not_materialized_outside_first_slice`
- `drift_integrity_evidence_not_materialized_outside_first_slice`

## Status rule

The core kernel operational status remains not closed until the closeout manifest criteria are satisfied across the broader kernel surface.

