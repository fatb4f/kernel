# Kernel Reference Workflow

This directory is downstream reference material. It is rendered from admitted state by Jsonnet and is not authoritative source material.

## Workflow

The kernel workflow is a fixed four-state pipeline:

```text
raw sources -> normalized state -> admitted state -> rendered artifacts
```

The canonical structural model is authoritative. JSON Structure is only an authoring syntax for that model. JSON Schema is a derived export boundary. CUE admits normalized state. Jsonnet renders from admitted state only.

## Operational planes

- `structures/` contains the canonical source model.
- `schemas/exported/` contains derived contracts only.
- `schemas/compatibility/` is limited to tightly controlled compatibility shims.
- `policy/` contains legality and admission logic.
- `render/jsonnet/` contains renderers that consume admitted state only.
- `manifests/` contains control objects for bundles, projections, and generators.
- `generated/` contains committed derived artifacts and evidence views.
- `build/` contains disposable local outputs only.

## Rendered pages

- [workflow.md](workflow.md)
- [gates.md](gates.md)
- [admission-artifacts.md](admission-artifacts.md)
- [operational-status.md](operational-status.md)
- [executable-slice.md](executable-slice.md)

## Source inputs

This reference set is aligned to:

- [kernel.spec.md](../../../kernel.spec.md)
- [kernel.spec.json](../../../kernel.spec.json)
- [reference-docs.libsonnet](../../../render/jsonnet/reference/reference-docs.libsonnet)
- [reference-docs.generator.json](../../../manifests/generators/reference-docs.generator.json)
- [reference-docs-executable-slice.module.json](../../../structures/core/reference-docs-executable-slice.module.json)
- [reference-docs-executable-slice.generator.json](../../../manifests/generators/reference-docs-executable-slice.generator.json)
- [reference-docs-executable-slice.projection.json](../../../manifests/projections/reference-docs-executable-slice.projection.json)

## Operational rule

No renderer, exporter, or compatibility shim may establish authority. Authority exists only in the canonical structural model under `structures/`.
