# Packet Definition - pkt-kernel-trust-spec-001

## Title
Kernel trust spec implementation for the dual-lane trust surface

## Status
- workflow_state: DEFINITION_APPROVED
- review_state: DEFINITION_APPROVED

## Summary
Implement the normative kernel trust spec as a dual-lane control surface. Root attestation establishes delegated authority, bundle sign exercises that authority over the concrete bundle payload, and packet-local evidence records the admission dependency chain. The kernel owns trust. The root public key, bundle-signer delegation, bundle signature, and bundle attestation are now materialized.

## Objectives
- preserve the root-lane and bundle-lane split
- keep packet-local evidence as an admission boundary only
- keep realization outside the ChatGPT boundary
- keep the trust surface backend-agnostic

## Constraints
- Keep the root key offline
- Do not collapse root attestation and bundle signing into one lane
- Do not treat packet-local evidence as a trust source
- Do not introduce a general-purpose PKI
- Do not claim cryptographic completion until the bundle-sign artifacts are materialized
- Use scm.pattern as the local realization surface
- Use repo-relative paths only
- packet.definition.json remains the canonical machine-readable packet artifact
- packet.approval.json, if retained, is superseded compatibility evidence only and non-authoritative
- problem_set is the only admissible ingress contract for generation

## Trust Surface
- control/trust/trust.spec.json
- control/trust/trust.spec.md
- control/trust/root.signers.json
- control/trust/delegations/chatgpt.packet-sidecar.json
- control/scm.pattern/authority.manifest.json
- manifests/bundles/bundle-closure.manifest.json

## Required Now
- generated/packets/pkt-kernel-trust-spec-001/machine/packet.definition.json
- generated/packets/pkt-kernel-trust-spec-001/machine/scm.pattern.binding.json
- generated/packets/pkt-kernel-trust-spec-001/machine/packet.review.request.json
- generated/packets/pkt-kernel-trust-spec-001/machine/root.trust.evidence.json
- generated/packets/pkt-kernel-trust-spec-001/machine/regen.record.json
- generated/packets/pkt-kernel-trust-spec-001/machine/artifact.manifest.json
- generated/packets/pkt-kernel-trust-spec-001/machine/packet.approval.json
- generated/packets/pkt-kernel-trust-spec-001/human/packet.definition.md

## Conditional Later
- generated/packets/pkt-kernel-trust-spec-001/machine/packet.review.decision.json

## Admissibility
- Kernel establishes trust root
- The delegation surface is shallow and bounded
- File presence alone never creates trust
- root.trust.evidence.json must carry canonical refs and fingerprints
- Root authorization and bundle signing are separate lanes
- Downstream artifacts must validate against their own declared schemas
- Human review remains separate from root trust

## Regen
- Regeneration is blocked unless required inputs change
