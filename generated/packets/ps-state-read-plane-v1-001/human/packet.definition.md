# Packet Definition - ps-state-read-plane-v1-001

## Title
Packet handoff: state-first read-plane architecture slice v1

## Status
- workflow_state: DEFINITION_UNDER_REVIEW
- review_state: DEFINITION_UNDER_REVIEW

## Summary
This packet carries the new `control/modules/state` architecture slice into kernel review. It is explicitly state-first: `get_state` and `hydrate_state` are the primary service surfaces, ACP is transport only, Marimo is registry/view consumer only, and issue #15 tracks the lifecycle.

## Inputs
- generated/problem_sets/ps-state-read-plane-v1-001/problem_set.json
- control/modules/state/module.root.v1.json
- control/modules/state/inventory.v1.json
- control/modules/state/namespace.contract.v1.json
- control/modules/state/workflow_dag.v1.md
- control/modules/state/dependency_order.v1.json
- control/modules/state/interop_matrix.v1.json
- schemas/control/module_root.schema.json
- schemas/control/module_inventory.schema.json
- schemas/control/module_namespace_contract.schema.json
- control/modules/README.md
- control/scm.pattern/authority.manifest.json

## Tracking
- issue: #15

## Constraints
- architecture-only and review-only
- no repo write path
- ACP remains transport only
- Marimo remains registry/view consumer only
- ChatGPT may not realize this packet
