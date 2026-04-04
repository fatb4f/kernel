# CLI Extension V2 Realization Workflow Contract

This contract defines the runtime-neutral realization boundary for the v2 CLI extension profile.

It does not define backend internals.

## Purpose

The realization workflow exists to:
- validate authority inputs
- bind semantic objects to approved adapter targets
- emit generated implementation and verification artifacts
- update projection manifests
- report deterministic realization status

## Canonical command

The realization workflow should expose one canonical command surface:

`control realize cli-extension-v2`

The exact implementation may vary, but the contract expects one stable entrypoint.

## Inputs

Required authority inputs:
- canonical semantic model
- `cli_role` constraint layer
- runtime-neutral extension profile
- projection manifest example or template
- adapter matrices as needed for selected backends

## Output roots

Generated outputs should remain under deterministic generated/build roots.

Expected first roots:
- `build/bashly/`
- `build/python/`
- `build/tests/shell/`
- `build/tests/python/`

## Binding rules

The realization workflow must:
1. resolve target bindings from the realization payload
2. confirm each target backend is allowed for its adapter family
3. confirm all referenced semantic objects exist
4. reject missing required semantic inputs
5. reject adapter-family and projection-role mismatches

## Emission classes

The workflow may emit:
- implementation config artifacts
- implementation runtime code artifacts
- verification artifacts
- projection manifest updates
- realization reports

It must not promote emitted artifacts to authority.

## Determinism rules

The workflow must be:
- replayable
- idempotent over generated outputs
- explicit about overwrite policy
- explicit about emitted repo paths

Formatting-only changes should not alter semantic realization status.

## Manifest obligations

A realization run must:
- bind each target to each emitted artifact
- record deterministic inputs
- record repo paths
- record projection kind

## Success conditions

A realization run is successful only if:
- all required artifacts are emitted
- manifest update obligations are satisfied
- there are no unresolved required semantic roles
- there are no adapter-family mismatches
- deterministic replay produces identical outputs

## Out of scope

This contract does not define:
- Bashly generator internals
- jsonargparse emitter internals
- Bats macro internals
- pytest fixture architecture

Those belong to adapter slices, not the realization boundary itself.
