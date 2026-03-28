# Amend kernel JSON-family and bridge actor declarations

## Contract
- `problem_set_id`: `ps-kernel-json-family-amendment-001`
- `status`: `draft`
- `version`: `0.3.0`
- `fingerprint`: `165b021ac35645140defba72dfb54de95889f91a7c8f6fb4689923c984ad9b98`

## Objective
Encode JSON Structure, bridge semantics, and derived runtime actor declarations in kernel control surfaces without redefining the existing authority routing.

## In Scope
- kernel-only amendment
- JSON-family decomposition
- bridge loss and promotion defaults
- runtime actor declarations
- lineage and evidence obligations

## Out Of Scope
- gpt-registry changes
- retrieval-pack updates
- AGENTS-only resolution
- promotion of bridge outputs into authority

## Constraints
- The canonical structural model remains the sole authority.
- JSON Structure remains authoring syntax only.
- JSON Schema remains a derived exported boundary contract.
- CUE remains admission over normalized state.
- Jsonnet remains rendering over admitted state only.
- Bridge outputs remain derived-only unless explicit promotion policy is added.

## Requested Outputs
- amendment packet
- affected refs
- dry-run admission report
- review request
- trust evidence bindings

## Authority Refs
- `kernel.spec.json`
- `generated/schemas/chatgpt-pipeline/workflow/problem_set.schema.json`
- `generated/schemas/chatgpt-pipeline/workflow/chatgpt.gate.policy.json`

## Acceptance Criteria
- The problem_set normalizes into a valid generated problem_set.json.
- Kernel-only scope controls are explicit in the normalized contract.
- The handoff issue body is renderable from the normalized contract.
- No gpt-registry refs are required for the amendment packet.

## Review Criteria
- Authority routing remains unchanged.
- Bridge outputs remain derived by default.
- Runtime actor declarations do not become authority objects.

## Scope Controls
- `forbidden_artifact_classes`: authority_promotion_of_bridge_output
- `forbidden_repos`: gpt-registry
- `forbidden_surfaces`: AGENTS.md, gpt-registry/**
- `target_artifact_classes`: extension_registry, bridge_registry, runtime_actor_registry, admission_policy, lineage_evidence
- `target_repos`: kernel
- `target_surfaces`: structures/extensions, policy/kernel, policy/admission, generated/registries, generated/state

## Handoff
- `issue_title_prefix`: `Packet handoff`
- `labels`: packet-handoff, problem-set, kernel

## Admission
- `decision`: `ALLOW`
- `policy_bundle_id`: `policy/admission/problem-set-surface.cue`
- `admitted_at`: `2026-03-28T02:55:38Z`

## Notes
- Rendered from admitted `problem_set` state only.
- Runtime actors remain derived operators after admission.

