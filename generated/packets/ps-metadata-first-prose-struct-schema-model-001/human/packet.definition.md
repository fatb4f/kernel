# Packet Definition - ps-metadata-first-prose-struct-schema-model-001

## Title
Packet handoff: metadata-first prose->struct->schema model kernel amendment

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
This packet derives from the validated metadata-first bundle and now carries the landed metadata metaschema lane slice as part of the review basis. Local validation may pass on the packet artifact family, but realization remains blocked until a human-issued review decision exists for the current packet basis.

## Inputs
- generated/problem_sets/ps-metadata-first-prose-struct-schema-model-001/problem_set.json
- generated/bundles/metadata-first-prose-struct-schema-model.bundle.tar.gz
- generated/registries/chatgpt-packet-family.index.json
- structures/extensions/metadata-metaschema-lane.module.json
- policy/kernel/metadata-metaschema-lane.index.json
- policy/data/metadata-lane-dependency.index.json
- policy/admission/metadata-metaschema-lane.cue
- schemas/exported/metadata-metaschema-lane-input.schema.json
- manifests/generators/metadata-metaschema-lane.generator.json
- manifests/projections/metadata-metaschema-lane.projection.json
- generated/registries/metadata-metaschema-lane.index.json
- generated/registries/metadata-lane-dependency.index.json
- generated/state/admission/metadata-metaschema-lane/2026-03-29T22-16-18Z/decision.json
- generated/state/render/metadata-metaschema-lane/2026-03-29T22-16-18Z/render-report.json
- generated/state/integrity/metadata-metaschema-lane/2026-03-29T22-16-18Z/drift-report.json
- generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json
- control/scm.pattern/authority.manifest.json
- control/trust/root.signers.json
- control/trust/delegations/chatgpt.packet-sidecar.json

## Constraints
- The validated bundle payload remains unchanged.
- The canonical semantic model remains the authoritative middle.
- Workflow docs remain explanatory only.
- The scm.pattern packet lane remains downstream of the metaschema model.
- Landed metadata metaschema lane outputs are part of the packet review basis.
- Packet kinds remain aligned with the approved ChatGPT packet family registry.
- All packet refs remain repo-relative.
- ChatGPT may author packet artifacts only and may not realize them.

## Required artifacts now
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/packet.definition.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/scm.pattern.binding.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/packet.review.request.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/root.trust.evidence.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/regen.record.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/artifact.manifest.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/packet.approval.json
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/human/packet.definition.md

## Conditional later
- generated/packets/ps-metadata-first-prose-struct-schema-model-001/machine/packet.review.decision.json

## Admission boundary
- Local runtime validates all required artifacts and refs
- Trust evidence fingerprints must match current file content
- Admission may pass before human review, but realization may not
- Human-issued review decision remains required for realization
