## Workflow

The kernel `problem_set` workflow is:

```text
prose
-> anchor map / extraction object
-> reviewed structural draft
-> JSON Structure contract
-> derived JSON Schema
-> normalized problem_set.json
-> CUE admission
-> Jsonnet render
-> evidence / handoff
```

## Stage meanings

### 1. Extraction

Extraction artifacts are **candidate interpretation surfaces** only.

Typical outputs:

* `anchor_map.json`
* `unknowns.json`
* `candidate_examples/`

These artifacts help reviewers move from weak prose to a reviewable structural draft, but they are **not authority**.

### 2. Structural authoring

The first contract surface is the **JSON Structure-authored structural draft**.

That is where the kernel-authorized shape becomes explicit. The structural contract may be authored directly or inferred from reviewed examples and then refined manually.

### 3. Boundary derivation

From the structural contract, derive:

* exported JSON Schema
* any consumer-facing bindings or schema views
* the normalized `problem_set.json` instance used by the packet lane

In this model:

* **JSON Structure** is authoring syntax
* **JSON Schema** is the exported boundary contract
* **problem_set.json** is the normalized instance for the specific run

### 4. Admission

CUE evaluates legality over normalized state.

Admission is where kernel policy decides whether the normalized `problem_set.json` is allowed to proceed. This is also where scope controls, review requirements, and promotion constraints are enforced.

### 5. Rendering

Jsonnet renders from admitted state only.

Rendered outputs may include:

* review documents
* summary objects
* evidence views
* handoff artifacts

These outputs are derived and non-authoritative.

## Boundary rules

* extraction artifacts must never be treated as authority
* JSON Structure is the first authored contract surface
* JSON Schema remains derived
* CUE admits normalized state only
* Jsonnet renders admitted state only
* runtime actors remain derived operators after admission

## Current kernel mapping

For the currently materialized `problem_set` surface:

* normalized instance:
  * `generated/problem_sets/<problem-set-id>/problem_set.json`
* admission policy:
  * `policy/admission/problem-set-surface.cue`
* admitted state:
  * `generated/state/admission/problem-set-surface/<run-id>/admitted-state.json`
* rendered outputs:
  * `generated/docs/problem-sets/<problem-set-id>.md`
  * `generated/state/render/problem-set-surface/<run-id>/problem-set.summary.json`

## Practical rule

Use extraction to discover structure.
Use JSON Structure to declare structure.
Use JSON Schema to export structure.
Use CUE to admit structure.
Use Jsonnet to render derived outputs.
