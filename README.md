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

This remains a structural baseline only. It does **not** implement normalize/admit/render or any controller/runtime logic.
