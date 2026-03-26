# Gates

The kernel workflow uses six gates. Each gate emits fixed evidence and fails closed on its deny condition.

| Gate | Name | Required evidence | Deny condition |
|---|---|---|---|
| G1 | Source validity | `source-validation.json` | parse or import failure |
| G2 | Contract export | `export-report.json` | regen drift or export failure |
| G3 | Normalization | `normalized-state.json`, `source-map.json`, `normalization-report.json` | nondeterminism or normalization failure |
| G4 | Admission | `decision.json`, `violations.json`, `admitted-state.json` | legality failure |
| G5 | Rendering | `render-report.json` | renderer reads non-admitted input or render failure |
| G6 | Drift and integrity | `drift-report.json` | unapproved diff, missing output, or hand-edited derived file |

## Reason codes

Reason codes should remain partitioned by family:

- `SRC_*`
- `EXPORT_*`
- `NORM_*`
- `ADMIT_*`
- `RENDER_*`
- `DRIFT_*`

## Gate meaning

- G1 checks whether the raw source plane is parseable and referentially coherent.
- G2 checks whether exported contracts match the canonical structural model.
- G3 checks whether normalization is deterministic and complete.
- G4 checks whether normalized state is legally admissible.
- G5 checks whether rendering only consumes admitted state.
- G6 checks for drift, missing outputs, and hand-edited derived files.
