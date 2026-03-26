# Operational Status

Current baseline status for the kernel-spec-defined workflow:

- `BLOCKED`

## Why

The core closeout target remains blocked, but the specific Jsonnet runtime blocker is resolved. The repository now has one executable end-to-end slice for `reference-docs-executable-slice`, including source validation, schema export, normalization, CUE admission, Jsonnet rendering, and drift checks.

## What is true

- The kernel spec is normative.
- The canonical structural model is authoritative.
- The workflow reference docs exist and mirror the spec-defined pipeline.
- The operational closeout checklist is present and acts as the core status gate.
- A local Jsonnet runtime is available via `rsjsonnet`.
- The first executable slice emits G1-G6 evidence under `generated/state/*/reference-docs-executable-slice/2026-03-26T23-05-00Z/`.

## What is blocking status closure

- `structures_core_not_fully_materialized`
- `schemas_exported_not_fully_materialized`
- `cue_policy_not_fully_materialized`
- `normalization_outputs_not_materialized_outside_first_slice`
- `admission_evidence_not_materialized_outside_first_slice`
- `render_evidence_not_materialized_outside_first_slice`
- `drift_integrity_evidence_not_materialized_outside_first_slice`

## Status rule

The core kernel operational status remains not closed until the executable workflow extends beyond the first bounded slice and the closeout manifest criteria are satisfied across the broader kernel surface.
