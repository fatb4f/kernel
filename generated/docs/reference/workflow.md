# Workflow

The kernel workflow is the authoritative source-to-render path for the repository.

## Fixed pipeline

```text
raw sources -> normalized state -> admitted state -> rendered artifacts
```

## Stage semantics

### Raw sources

The authoring plane. Humans and AI edit canonical structural source here, plus manifest control objects that declare bundles, projections, and generators.

### Normalized state

Normalization regularizes structure only. It may resolve imports, canonicalize aliases, apply declared defaults, normalize ordering and shape, expand declared composition, and preserve provenance.

Normalization must not decide legality, invent facts, silently discard source information, resolve semantic conflicts without evidence, or render final artifacts.

### Admitted state

Admission evaluates legality over normalized state only. It emits explicit decision evidence and produces the renderer-visible dataset.

### Rendered artifacts

Jsonnet renders from admitted state only. Renderers must not read raw authoring sources directly.

## Plane boundaries

- `structures/` is the canonical source plane.
- `schemas/exported/` is the derived contract plane.
- `schemas/compatibility/` is restricted compatibility surface only.
- `policy/` is the admission plane.
- `render/jsonnet/` is the rendering plane.
- `manifests/` is the control-object plane.
- `generated/` is committed derived output and evidence.
- `build/` is ephemeral local materialization.

## Implementation rule

Downstream compatibility hacks must not become authority. If a compatibility shim exists, it remains subordinate to the canonical structural model.
