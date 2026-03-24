# Kernel Spec v1

## 1. Purpose

Define the accepted kernel baseline as the authoritative architecture for the repository. This document fixes the authority model, state flow, plane boundaries, repository semantics, invariants, artifact classes, gate model, and admission artifact convention required to move from architecture to enforcement.

This document is normative for the kernel baseline.

---

## 2. Authority Model

```text
canonical structural model = authority
JSON Structure             = authoring syntax
JSON Schema                = exported boundary contract
CUE                        = admission over normalized state
Jsonnet                    = rendering over admitted state
Structurize/Avrotize       = derived interop/codegen bridge
```

### Authority interpretation

- The canonical structural model is authoritative.
- JSON Structure is an authoring syntax for that model, not the authority itself.
- JSON Schema is derived for exported boundary contracts and interoperability.
- CUE evaluates legality over normalized state.
- Jsonnet renders artifacts from admitted state only.
- Structurize/Avrotize is a derived interop and codegen bridge.

---

## 3. State Flow

```text
raw sources -> normalized state -> admitted state -> rendered artifacts
```

### Core invariant

```text
Normalization regularizes form only.
Admission decides legality.
Rendering consumes admitted state only.
```

### Boundary rules

- Normalization may regularize, resolve, and canonicalize.
- Admission determines legality, completeness, and allowed composition.
- Rendering consumes admitted state only.
- Jsonnet must never read raw authoring sources directly.

---

## 4. Plane Boundaries

### Structure plane
Human-authored canonical model.

- small modules
- reusable fragments
- relations
- overlays/adapters
- no downstream compatibility hacks as authority

### Contract plane
Derived machine-facing contracts.

- exported JSON Schema
- interoperability surfaces
- validator/codegen consumer contracts
- not authoritative

### Policy plane
Admission and legality over normalized state.

- CUE admission bundles
- cross-document invariants
- required/forbidden combinations
- bundle and profile legality

### Artifact plane
Derived rendered outputs.

- docs
- registries
- configs
- codegen inputs
- review views
- CI-facing rendered outputs

---

## 5. Repo Semantics

- `structures/` = canonical source model
- `schemas/exported/` = derived contracts
- `schemas/compatibility/` = tightly controlled compatibility shims only
- `policy/` = legality and admission logic
- `render/jsonnet/` = rendering layer over admitted state
- `manifests/` = control objects declaring bundles, projections, and generators
- `generated/` = committed derived artifacts and evidence views
- `build/` = disposable local outputs

---

## 6. Frozen Physical Repo Tree

```text
kernel/
  structures/
    core/
    extensions/
    relations/
    adapters/

  schemas/
    exported/
    compatibility/

  policy/
    kernel/
    admission/
    data/

  render/
    jsonnet/

  manifests/
    bundles/
    projections/
    generators/

  examples/
    valid/
    invalid/
    composed/

  generated/
    docs/
    schemas/
    registries/
    state/

  build/
```

### Physical baseline freeze

- No top-level `state/` directory unless it is later reintroduced as a source declaration area.
- `generated/` contains committed derived artifacts and committed review/evidence views.
- `build/` contains ephemeral local materialization only.

---

## 7. Normalization Contract

Normalization transforms raw source material into a regularized kernel dataset suitable for admission.

### Allowed operations

- resolve imports and references
- canonicalize aliases
- apply declared defaults
- normalize ordering and container shape
- expand declared composition into explicit normalized objects
- preserve provenance links to source modules

### Forbidden operations

- decide legality or admissibility
- invent semantic facts
- silently discard source information unless declared
- resolve semantic conflicts without emitting evidence
- render final downstream artifacts

### Required normalization outputs

- `normalized-state.json`
- `source-map.json`
- `normalization-report.json`

---

## 8. Admission Contract

Admission evaluates legality over normalized state.

### Admission responsibilities

- evaluate legality
- evaluate completeness
- evaluate allowed composition
- emit explicit decision artifacts

### Admission evidence

- `decision.json`
- `violations.json`
- `admitted-state.json`

---

## 9. Rendering Contract

Rendering consumes admitted state only.

### Rendering rules

- Jsonnet renders from admitted state only.
- Renderers must never read raw authoring sources directly.
- Every renderer declares its admitted-state inputs and output class.

---

## 10. Frozen Invariants

1. Canonical model is authoritative; exports are derived.
2. Exported schemas are not hand-edited.
3. CUE admits normalized state, not arbitrary mixed inputs.
4. Jsonnet renders from admitted state only.
5. `generated/` is committed derived state; `build/` is ephemeral.
6. Every bundle, projection, and generator is declared by a manifest control object.
7. Every committed derived artifact must be regen-clean.
8. Normalization regularizes structure only; it does not decide legality.
9. Every admission run emits an explicit decision artifact.
10. Every renderer declares its admitted-state inputs and output class.
11. Toolchain versions for normalize/admit/render are pinned or policy-controlled.

---

## 11. Artifact Classes

Minimum output classes:

- `contract-export`
- `review-view`
- `runtime-config`
- `registry`
- `documentation`
- `codegen-input`
- `admitted-state`
- `admission-decision`
- `admission-violations`

---

## 12. Gate Model

Use stable gate IDs.

| Gate ID | Name | Inputs | Tool/Layer | Required evidence | Deny condition |
|---|---|---|---|---|---|
| G1 | Source validity | raw sources | parser/SDK | `source-validation.json` | parse or import failure |
| G2 | Contract export | canonical model | exporter | `export-report.json` | regen drift or export failure |
| G3 | Normalization | raw sources | normalizer | `normalized-state.json`, `source-map.json`, `normalization-report.json` | nondeterminism or normalization failure |
| G4 | Admission | normalized state | CUE | `decision.json`, `violations.json`, `admitted-state.json` | legality failure |
| G5 | Rendering | admitted state | Jsonnet | `render-report.json` | renderer reads non-admitted input or render failure |
| G6 | Drift and integrity | generated outputs | CI checks | `drift-report.json` | unapproved diff, missing output, or hand-edited derived file |

### Recommended reason-code families

```text
SRC_*
EXPORT_*
NORM_*
ADMIT_*
RENDER_*
DRIFT_*
```

---

## 13. Admission Artifact Convention

### Required files

```text
decision.json
violations.json
admitted-state.json
```

### Path convention

```text
generated/state/admission/<control-object-id>/<run-id>/
```

### Run id convention

Use either:

- sortable ISO-like timestamp, or
- monotonic build identifier

### Minimum semantics

- `decision.json` = allow/deny summary, policy bundle id, input digests, tool versions
- `violations.json` = machine-readable list, empty on allow
- `admitted-state.json` = exact renderer-visible admitted dataset

---

## 14. Implementation Order

```text
Phase 1: KERNEL_SPEC.md
Phase 2: manifests/kernel.bundle.schema.json
Phase 3: manifests/output-classes.schema.json
Phase 4: policy/contracts/normalization.md
Phase 5: ci/gate-matrix.md
Phase 6: admission artifact materialization
```

### Contract pack v1 completion condition

Contract pack v1 is complete when:

- prose authority exists
- control objects validate
- outputs are typed
- normalization boundary is explicit
- gate IDs and evidence artifacts are fixed
- admission artifacts are no longer implicit
