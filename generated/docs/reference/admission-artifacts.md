# Admission Artifacts

Admission evidence is materialized under:

```text
generated/state/admission/<control-object-id>/<run-id>/
```

The `run-id` must be sortable, using an ISO-like timestamp, a monotonic build identifier, or both.

## Required files

- `decision.json`
- `violations.json`
- `admitted-state.json`

## Minimum semantics

- `decision.json` contains the allow/deny summary, policy bundle ID, input digests, and tool versions.
- `violations.json` contains a machine-readable list and must be empty on allow.
- `admitted-state.json` is the exact renderer-visible admitted dataset.

## Operational rule

Admission evidence is not optional or implicit. If it does not exist in the admission directory, the workflow is not complete.
