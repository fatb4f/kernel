# Gate Matrix

| Gate | Name | Required Evidence | Deny Condition |
| ---- | ---- | ----------------- | -------------- |
| G1 | Source validity | `source-validation.json` | parse or import failure |
| G2 | Contract export | `export-report.json` | regen drift or export failure |
| G3 | Normalization | `normalized-state.json`, `source-map.json`, `normalization-report.json` | nondeterminism or normalization failure |
| G4 | Admission | `decision.json`, `violations.json`, `admitted-state.json` | legality failure |
| G5 | Rendering | `render-report.json` | renderer reads non-admitted input or render failure |
| G6 | Drift and integrity | `drift-report.json` | unapproved diff, missing output, or hand-edited derived file |

## Reason-code families

- `SRC_*`
- `EXPORT_*`
- `NORM_*`
- `ADMIT_*`
- `RENDER_*`
- `DRIFT_*`

This file materializes the gate matrix called for by the kernel spec implementation order.
