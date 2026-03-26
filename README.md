# Corrected kernel skeleton

This scaffold corrects the uploaded physical skeleton to match the normative repo tree declared in `kernel.spec.json`.

## Corrections applied

- `manifest/` replaced with `manifests/`
- nested directories created under:
  - `structures/`
  - `schemas/`
  - `policy/`
  - `render/`
  - `manifests/`
  - `examples/`
  - `generated/`
- `build/` retained as disposable area only

## pkt-r07 structural translation state

`pkt-r07` is now structurally complete for:

- boundary-object partition
- schema partition
- example partition
- generated-vs-build policy formalization

## Notes

This repo is no longer a structural baseline only.

The first executable slice is now materialized for `reference-docs-executable-slice`, including:

- authoritative source under `structures/`
- derived schema export under `schemas/exported/`
- normalization outputs under `generated/state/normalization/`
- CUE admission artifacts under `generated/state/admission/`
- Jsonnet-rendered documentation under `generated/docs/reference/executable-slice.md`

The broader kernel-core closeout remains incomplete. Other source families, generators, admission bundles, and rendered outputs are still only partially materialized.
