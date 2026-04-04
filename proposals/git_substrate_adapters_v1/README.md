# Git Substrate Adapters V1 Proposal

This proposal defines and closes the first Git-substrate adapter tranche on top of the stabilized CLI realization pattern.

It exists to:
- classify `gix` and `sem` as projected Git-substrate adapters
- keep canonical metadata authority separate from Git adapter outputs
- define the first target-contract boundary for deterministic Git-state and semantic-diff projections
- reuse the normalized realization pattern instead of inventing a parallel adapter workflow

Files:
- `spec_draft.v1.json`
- `extension_profile.v1.json`
- `canonical_semantic_model.git.example.json`
- `projection_artifact_manifest.git.example.json`
- `realization_payload.v1.json`
- `compatibility_assessment.v1.json`
- `realization_workflow_contract.v1.md`
- `control_realize_git_substrate_adapters_v1.py`
- `test_control_realize_git_substrate_adapters_v1.py`
- `git_projection_common.py`
- `emit_gix_minimal.py`
- `test_emit_gix_minimal.py`
- `emit_sem_minimal.py`
- `test_emit_sem_minimal.py`
- `gix_target_contract.v1.json`
- `sem_target_contract.v1.json`
- `gix_runtime_contract.v1.json`
- `sem_runtime_contract.v1.json`
- `gix_runtime_helper/Cargo.toml`
- `gix_runtime_helper/Cargo.lock`
- `gix_runtime_helper/src/main.rs`
- `git_capability_service_policy.v1.json`
- `git_capability_service_api_contract.v1.json`
- `git_capability_service_workflow_dag.v1.md`
- `shell_port_inventory.v1.json`
- `python_port_inventory.v1.json`
- `proposal_register.v1.json`
- `gate_result.v1.json`

Current status:
- proposal tranche for Git-substrate projected adapters
- `gix` is scoped as the deterministic Git fact surface
- `sem` is scoped as the semantic diff enrichment surface
- target contracts exist at the proposal boundary
- a first Git-substrate semantic example now exists
- a first Git-substrate realization payload now exists
- compatibility posture for `git_substrate_role` now exists
- a first Git-substrate realization workflow contract now exists
- a first Git-substrate realization runner now exists and emits normalized manifest/report artifacts
- the runner-owned Git transform logic is now split into narrower `gix` and `sem` projection emitters
- real-runtime contracts for `gix` and `sem` are now explicit
- first shell and Python port inventories now exist for the repo-local scripts
- `sem` now has a real local runtime path through the checked-out `ataraxy/sem` source tree
- `gix` now has a real local runtime path through a repo-local Rust helper that uses the `gix` crate directly
- `gix` and `sem` are closed for this tranche through `adapter_closeout.v1.json`
- a policy-enforced Git capability service contract now exists for operationalizing the runtime surfaces without exposing a generic Git shell
- a workflow DAG now exists for the service architecture and synced script-migration flow with `just` as the entrypoint module

Direction:
- canonical metadata remains authority
- runtime assets remain projection-only
- Git adapter outputs are structured operational artifacts, not authority
- `gix` and `sem` are projected adapters over the Git substrate
- implementation reuses the normalized realization pattern already established in `cli_extension_v2`
- the unified runner remains the primary operator surface and owns aggregation plus normalized manifest/report emission
- `emit_gix_minimal.py` and `emit_sem_minimal.py` are bounded projection surfaces under that runner
- runtime contracts now separate minimal projection proof from crate-backed/local-backend integration work
- adapter closeout is explicit for the first real-runtime tranche
- policy-enforced Git access is modeled as a capability service with task-shaped operations and deterministic gates outside the model
- port inventories now separate real operator-entrypoint migration candidates from projection internals
- the runner now distinguishes real backend execution from minimal fallback in backend reports
- the `gix` runtime path is crate-backed and does not rely on parsing the `gix` CLI output surface
