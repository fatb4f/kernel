# Policy / Admission

This directory contains admission-relevant policy.

The first executable slice is now materialized at:

- `policy/admission/reference-docs-executable-slice.cue`

Allowed content in this tranche:

- scope statements for later admission over normalized state
- placeholder declarations of admission-relevant state families
- non-runnable notes about what future admission policy may evaluate
- runnable CUE admission bundles for bounded kernel slices that consume normalized state only

Not allowed in this tranche:

- runnable normalize/admit behavior
- Cargo / `just` / script orchestration
- provider workflow logic
- loop-pipeline execution semantics

Runner orchestration remains outside this directory. This directory owns policy only.
