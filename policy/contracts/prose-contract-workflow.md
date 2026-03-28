# Prose Contract Workflow

## reviewed-structural-draft

The reviewed structural draft is the pre-contract review artifact derived from prose or extraction outputs and used to refine structure before promotion into the first authored contract surface.

## graph-boundary

An intermediate or graph-like representation may be used as an auxiliary workflow aid for extraction, review, diagnostics, or draft refinement.

It is optional and non-authoritative.

Kernel-lane generation proceeds from the reviewed structural draft and then the JSON Structure contract, not from the graph itself.

The graph is not a required contract surface, not a required generation input, and not an authority-bearing object.

## derived-artifact-family

Derived admission and export artifacts are generated from normalized or admitted contract state and do not replace the authored contract surface.

This family includes at minimum:

- `decision.json`
- `violations.json`
- `admitted-state.json`
- `schema.base.json`
- `constraints.manifest.json`
- `constraint-preservation.report.json`

Rules:

- these artifacts are derived, not authoritative, unless explicit promotion policy states otherwise
- no admitted constraint may be silently weakened or dropped
- any constraint not preserved in the structural export must be carried explicitly in a derived constraint-facing artifact and reported

## consumer-export-policy

The preferred external contract bundle is:

- `schema.base.json`
- `constraints.manifest.json`
- `constraint-preservation.report.json`

An optional merged convenience export may exist, but only as a derived view. It must not replace the explicit structural export plus constraint sidecar as the preferred consumer shape.
