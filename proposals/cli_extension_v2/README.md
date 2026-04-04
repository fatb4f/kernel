# CLI Extension V2 Proposal

This proposal generalizes the shell-first extension profile into a runtime-neutral CLI profile.

It does not rewrite or invalidate the approved first shell slice.

It exists to:
- replace `shell_cli_role` with `cli_role`
- replace shell-specific lineage wording with runtime-neutral wording
- split implementation and verification targets by runtime family

Files:
- `basis/metadata/canonical_semantic_model.schema.json`
- `basis/metadata/projection_artifact_manifest.schema.json`
- `basis/shell_cli_extension/extension_profile.v1.json`
- `basis/shell_cli_extension/extension_constraints.example.json`
- `basis/shell_cli_extension/python_cli_prospect.v1.md`
- `basis/shell_cli_extension/jsonargparse_projection_matrix.v1.json`
- `spec_draft.v2.json`
- `proposal_register.v2.json`
- `gate_result.v2.json`
- `extension_profile.v2.json`
- `extension_constraints.v2.json`
- `extension_constraints.v2.schema.json`
- `canonical_semantic_model.cli.example.json`
- `projection_artifact_manifest.cli.example.json`
- `compatibility_assessment.v2.json`
- `realization_payload.v2.json`
- `realization_workflow_contract.v2.md`
- `bashly_target_contract.minimal.v1.json`
- `bashly_target_contract.minimal.v1.md`
- `emit_bashly_minimal.py`
- `test_emit_bashly_minimal.py`
- `jsonargparse_target_contract.minimal.v1.json`
- `jsonargparse_target_contract.minimal.v1.md`
- `emit_jsonargparse_minimal.py`
- `test_emit_jsonargparse_minimal.py`
- `control_realize_cli_extension_v2.py`
- `test_control_realize_cli_extension_v2.py`
- `unified_realization_manifest.v2.schema.json`
- `unified_realization_report.v2.schema.json`
- `hof_prospect.v1.md`

Current status:
- proposal draft with runtime-neutral constraints, example artifacts, and compatibility assessment
- portable review basis is vendored locally under `basis/`
- realization boundary is now defined for adapter-facing follow-on slices
- the first concrete Bashly realization target is now wired to the upstream `examples/minimal` shape
- the first concrete Bashly minimal emitter now exists and emits `src/bashly.yml` plus `src/root_command.sh`
- the first concrete jsonargparse minimal target and emitter now exist for the Python implementation lane
- the broader realization runner now orchestrates both bounded implementation slices and emits the unified build tree
- the broader realization runner now owns the unified manifest/report contract and the verification-consumer projection outputs
- the broader realization runner now synthesizes the Bats and pytest verification projections from canonical verification and output semantics instead of copying child-emitter test sources

Direction:
- canonical metadata model remains authority
- runtime assets remain projection-only
- shell and Python adapters become runtime families under one CLI profile
- the first Bashly adapter slice is intentionally bounded to `src/bashly.yml` plus `src/root_command.sh`
- the first jsonargparse adapter slice is intentionally bounded to `parser.py` plus `test_control_plane_inspect.py`
- downstream `bashly generate` remains a distinct second-stage build and is reported honestly when unavailable in the environment
- the canonical runner is `control_realize_cli_extension_v2.py` and is now the primary operator surface for this lane
- bounded emitters remain internal projection surfaces under the unified runner
- the unified runner owns the normalized realization manifest/report contract and emits runner-owned Bats/pytest verification projections derived from canonical verification semantics
- `hof` is tracked as a projection-generation-orchestration prospect, not a runtime adapter
