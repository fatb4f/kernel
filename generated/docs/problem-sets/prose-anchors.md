## Prose Anchors

This document describes the **extraction-stage guidance** for turning weak prose into candidate structural inputs for the kernel `problem_set` workflow.

It is intentionally **not** an authority surface.

## Role

Use prose-anchor tooling to identify:

* candidate entities
* candidate fields
* candidate relations
* candidate constraints
* unresolved questions

These outputs are review aids. They help move prose toward a structural draft, but they do not define the kernel contract on their own.

## Extraction model

Recommended front end:

1. deterministic anchor spotting
2. structured extraction into typed candidate objects
3. review and example synthesis
4. JSON Structure authoring or refinement
5. downstream derivation and admission

That gives the kernel a clean separation between:

* **candidate extraction**
* **structural authoring**
* **policy admission**
* **derived rendering**

## Suggested extraction outputs

### 1. Anchor map

Capture anchored spans and their candidate interpretations:

```json
{
  "document_id": "doc-001",
  "anchors": [
    {
      "text": "customer name",
      "anchor_type": "field",
      "proposed_path": "customer.name",
      "confidence": 0.97,
      "source_method": "rule"
    }
  ]
}
```

### 2. Unknowns

Track missing or ambiguous structure explicitly:

```json
{
  "document_id": "doc-001",
  "unknowns": [
    "Whether status is a free-form string or enum",
    "Whether eta is optional or required"
  ]
}
```

### 3. Candidate examples

Build a small set of candidate example instances to support review and structural authoring.

## Boundary rule

The extraction object must never become authority.

The correct order is:

```text
prose
-> anchor_map / extraction object
-> reviewed structural draft
-> JSON Structure contract
-> derived JSON Schema
-> normalized problem_set.json
-> CUE admission
-> Jsonnet render
```

## Kernel interpretation

For kernel:

* extraction artifacts are **candidate interpretation surfaces**
* the JSON Structure-authored draft is the first contract surface
* normalized `problem_set.json` is the canonical run instance
* CUE decides admissibility
* Jsonnet renders derived review and handoff outputs

## Practical recommendation

Use hybrid extraction for prose:

* deterministic anchors first when domain vocabulary is stable
* structured extraction second for typed candidates
* review and examples before structural promotion

Then promote only the reviewed structural draft into the JSON Structure authoring layer.
