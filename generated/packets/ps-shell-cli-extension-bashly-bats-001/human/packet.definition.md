# Packet Definition - ps-shell-cli-extension-bashly-bats-001

## Title
Packet handoff: shell/CLI extension first amendment slice (Bashly + Bats)

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
This packet derives from the shell/CLI extension first amendment slice bundle and carries the landed metadata metaschema lane as upstream review basis. Local validation may pass on the packet artifact family, but realization remains blocked until a human-issued review decision exists for the current packet basis.

## Inputs
- generated/problem_sets/ps-shell-cli-extension-bashly-bats-001/problem_set.json
- generated/bundles/shell-cli-extension-bashly-bats.bundle.tar.gz
- generated/bundles/shell-cli-extension-bashly-bats.bundle.tar.gz.sha256
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

## Constraints
- The transport bundle payload must remain byte-identical during packet generation.
- The canonical metadata model remains the authority baseline for this extension slice.
- Shell assets remain projection-only and may not become semantic authority through this packet.
- The first amendment slice is limited to Bashly implementation projection and Bats verification projection.
- The scm.pattern packet lane remains a downstream operational carrier and must not define shell semantics.
- Packet input and deliverable kinds must remain aligned with the approved ChatGPT packet family registry.
- The landed metadata metaschema lane remains part of the packet review basis.
- All packet refs must remain repo-relative.

## Required artifacts now
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/packet.definition.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/scm.pattern.binding.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/packet.review.request.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/root.trust.evidence.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/regen.record.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/artifact.manifest.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/packet.approval.json
- generated/packets/ps-shell-cli-extension-bashly-bats-001/human/packet.definition.md

## Conditional later
- generated/packets/ps-shell-cli-extension-bashly-bats-001/machine/packet.review.decision.json

## Admission boundary
- Local runtime validates all required artifacts and refs
- Trust evidence fingerprints must match current file content
- Admission may pass before human review, but realization may not
- Human-issued review decision remains required for realization
