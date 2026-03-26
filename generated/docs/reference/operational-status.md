# Operational Status

Current baseline status for the kernel-spec-defined workflow:

- `BLOCKED`

## Why

The workflow is structurally in place and the closeout checklist items are done, but the local render lane is not executable because the Jsonnet CLI/runtime is not available on this machine.

## What is true

- The kernel spec is normative.
- The canonical structural model is authoritative.
- The workflow reference docs exist and mirror the spec-defined pipeline.
- The operational closeout checklist is present and acts as the core status gate.

## What is blocking status closure

- `jsonnet_cli_missing`
- `jsonnet_runtime_unavailable`

## Status rule

The core kernel operational status remains not closed until the render lane can be executed locally.
