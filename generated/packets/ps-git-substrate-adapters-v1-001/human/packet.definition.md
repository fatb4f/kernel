# Packet Definition - ps-git-substrate-adapters-v1-001

## Title
Packet handoff: Git-substrate adapter realization slice v1 kernel amendment

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
This packet derives from the Git-substrate adapter realization slice bundle and carries both the landed metadata metaschema lane and the normalized manifest/report pattern as review basis. Local validation may pass on the packet artifact family, but realization remains blocked until a human-issued review decision exists for the current packet basis.

## Inputs
- generated/problem_sets/ps-git-substrate-adapters-v1-001/problem_set.json
- generated/bundles/git-substrate-adapters-v1.bundle.tar.gz
- generated/bundles/git-substrate-adapters-v1.bundle.tar.gz.sha256
- generated/registries/chatgpt-packet-family.index.json
- structures/extensions/metadata-metaschema-lane.module.json
- policy/kernel/metadata-metaschema-lane.index.json
- policy/data/metadata-lane-dependency.index.json
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
- generated/schemas/chatgpt-pipeline/packet/packet.definition.schema.json
- generated/schemas/chatgpt-pipeline/packet/scm.pattern.binding.schema.json
- generated/schemas/chatgpt-pipeline/packet/packet.review.request.schema.json
- generated/schemas/chatgpt-pipeline/packet/root.trust.evidence.schema.json
- generated/schemas/chatgpt-pipeline/packet/regen.record.schema.json
- generated/schemas/chatgpt-pipeline/packet/artifact.manifest.schema.json
- generated/schemas/chatgpt-pipeline/packet/packet.approval.schema.json
- generated/schemas/chatgpt-pipeline/packet/packet.review.decision.schema.json
- generated/schemas/chatgpt-pipeline/packet/authority.manifest.schema.json

## Constraints
- The transport bundle payload must remain byte-identical during packet generation.
- The canonical metadata model remains the authority baseline.
- Git adapter outputs remain projection-only and do not become semantic authority.
- Deterministic Git fact capture must precede semantic diff enrichment.
- The normalized manifest/report pattern from cli_extension_v2 remains part of the realization basis.
- Packet input and deliverable kinds must remain aligned with the approved ChatGPT packet family registry.
- All packet refs must remain repo-relative.
- ChatGPT may author packet artifacts only and may not realize them.

## Required artifacts now
- generated/packets/ps-git-substrate-adapters-v1-001/machine/packet.definition.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/scm.pattern.binding.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/packet.review.request.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/root.trust.evidence.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/regen.record.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/artifact.manifest.json
- generated/packets/ps-git-substrate-adapters-v1-001/machine/packet.approval.json
- generated/packets/ps-git-substrate-adapters-v1-001/human/packet.definition.md

## Conditional later
- generated/packets/ps-git-substrate-adapters-v1-001/machine/packet.review.decision.json

## Admission boundary
- Local runtime validates all required artifacts and refs
- Trust evidence fingerprints must match current file content
- Admission may pass before human review, but realization may not
- Human-issued review decision remains required for realization
