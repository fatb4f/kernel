# Shell CLI Extension Proposal

This proposal extends the existing metadata model for shell and CLI semantics without introducing a parallel shell authority model.

Files:
- `spec_draft.v1.json`
- `proposal_register.v1.json`
- `gate_result.v1.json`
- `extension_profile.v1.json`
- `extension_constraints.schema.json`
- `extension_constraints.example.json`
- `amendment_slice.bashly_bats.v1.json`
- `bashly_projection_matrix.v1.json`
- `bashly_schema_crosswalk.v1.md`
- `python_cli_prospect.v1.md`
- `jsonargparse_projection_matrix.v1.json`
- `canonical_semantic_model.shell_cli.example.json`
- `projection_artifact_manifest.shell_cli.example.json`

Current status:
- proposal-ready for amendment review, with schema-backed extension constraints in place

Direction:
- canonical metadata model remains authority
- shell implementation backends are projection targets
- shell verification backends are projection consumers
- shell/CLI extension rules are constrained explicitly without modifying the base metadata schemas
- first amendment-facing slice is scoped to `Bashly` + `Bats`
- Bashly is reduced to adapter primitives, required config surfaces, and a projection matrix rather than treated as authority
- the Bashly schema crosswalk is the human-readable companion to the projection matrix
- Python CLI prospecting is captured as a follow-on normalization artifact rather than folded into the first shell slice
- `jsonargparse` is recorded as the current strongest first Python CLI adapter target
