# Packet Definition — ps-kernel-json-family-amendment-001

## Title
Packet handoff: ps-kernel-json-family-amendment-001 regeneration against locked chatgpt-pipeline contract

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
This packet derives from the problem_set `ps-kernel-json-family-amendment-001` and is submitted for human review before any realization. Local validation can pass on the current artifact family, but realization remains blocked until a human-issued review decision exists.

## Inputs
- generated/problem_sets/ps-kernel-json-family-amendment-001/problem_set.json
- generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.packet.pipeline.manifest.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.execution.policy.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.validation.manifest.json
- generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json
- control/scm.pattern/authority.manifest.json
- control/trust/root.signers.json
- control/trust/delegations/chatgpt.packet-sidecar.json

## Constraints
- The canonical structural model remains the sole authority.
- Bridge outputs remain derived-only unless explicit promotion policy is added.
- All packet refs must remain repo-relative.
- ChatGPT may author packet artifacts only and may not realize them.

## Required artifacts now
- generated/packets/ps-kernel-json-family-amendment-001/machine/packet.definition.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/scm.pattern.binding.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/packet.review.request.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/root.trust.evidence.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/regen.record.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/artifact.manifest.json
- generated/packets/ps-kernel-json-family-amendment-001/machine/packet.approval.json
- generated/packets/ps-kernel-json-family-amendment-001/human/packet.definition.md

## Conditional later
- generated/packets/ps-kernel-json-family-amendment-001/machine/packet.review.decision.json

## Admission boundary
- Local runtime validates all required artifacts and refs
- Trust evidence fingerprints must match current file content
- Admission may pass before human review, but realization may not
- Human-issued review decision remains required for realization
