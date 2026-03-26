# Packet Definition — pkt-kernel-chain-of-trust-001

## Title
Kernel chain-of-trust implementation for temporary ChatGPT packet sidecar

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
Implement the kernel-owned chain of trust for the temporary ChatGPT packet sidecar without deepening the sidecar into kernel-core. Kernel establishes the trust root. The sidecar consumes delegated trust only.

## Constraints
- Shallow, temporary sidecar only
- Do not deepen into kernel-core
- Do not introduce separate plan or implement artifact families
- Use scm.pattern as the local realization surface
- Use repo-relative paths only
- packet.definition.json remains canonical
- scm.pattern.binding.json remains mandatory
- packet.review.request.json is the pre-decision artifact
- packet.review.decision.json exists only after a human decision
- root.trust.evidence.json defines the packet-local trust boundary
- regen.record.json is required while the packet is under review
- packet.approval.json is transitional only if retained

## Kernel trust requirements
- control/trust/root.signers.json
- control/scm.pattern/authority.manifest.json
- control/scm.pattern/authority.manifest.validation.json
- control/scm.pattern/authority.manifest.signature.json
- control/trust/delegations/chatgpt.packet-sidecar.json

## Required now
- generated/packets/pkt-kernel-chain-of-trust-001/machine/packet.definition.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/scm.pattern.binding.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/packet.review.request.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/root.trust.evidence.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/regen.record.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/artifact.manifest.json
- generated/packets/pkt-kernel-chain-of-trust-001/machine/packet.approval.json
- generated/packets/pkt-kernel-chain-of-trust-001/human/packet.definition.md

## Conditional later
- generated/packets/pkt-kernel-chain-of-trust-001/machine/packet.review.decision.json

## Admissibility
- Kernel establishes trust root
- The sidecar consumes delegated trust only
- File presence alone never creates trust
- root.trust.evidence.json must carry canonical refs and fingerprints
- Validation and signature refs must both resolve and match
- Delegation must verify and remain in scope
- Downstream artifacts must validate against their own declared schemas
- Human review remains separate from root trust

## Regen
- Regeneration is blocked unless required inputs change

