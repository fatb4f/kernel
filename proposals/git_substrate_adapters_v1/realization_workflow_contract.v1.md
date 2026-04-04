# Git Substrate Adapters V1 Realization Workflow Contract

This contract defines the realization boundary for the first Git-substrate adapter slice.

It does not define `gix` or `sem` internals.

## Purpose

The realization workflow exists to:
- validate authority inputs
- bind Git semantic objects to approved adapter targets
- emit deterministic state and enrichment artifacts
- update projection manifests
- report realization status through the normalized manifest/report pattern

## Canonical command

The realization workflow should expose one canonical command surface:

`control realize git-substrate-adapters-v1`

The exact implementation may vary, but the contract expects one stable entrypoint.

## Inputs

Required authority inputs:
- canonical semantic model
- Git-substrate extension profile
- projection manifest example or template
- target contracts for the selected Git adapter backends

## Output roots

Generated outputs should remain under deterministic generated/build roots.

Expected first roots:
- `build/git/`

Optional later roots:
- `build/hydration/`

## Binding rules

The realization workflow must:
1. resolve target bindings from the realization payload
2. confirm each target backend is allowed for its adapter family
3. confirm all referenced semantic objects exist
4. reject missing required semantic inputs
5. reject adapter-family and projection-role mismatches
6. reject semantic enrichment targets that do not name an upstream deterministic diff input

## Emission classes

The workflow may emit:
- deterministic repository-state artifacts
- deterministic diff-state artifacts
- semantic-diff enrichment artifacts
- projection manifest updates
- realization reports

It must not promote emitted artifacts to authority.

## Determinism rules

The workflow must be:
- replayable
- idempotent over generated outputs
- explicit about overwrite policy
- explicit about emitted repo paths
- explicit about the upstream Git comparison inputs used for state and enrichment

Formatting-only changes should not alter semantic realization status.

## Manifest obligations

A realization run must:
- bind each target to each emitted artifact
- record deterministic semantic inputs
- record repo paths
- record projection kind
- record the upstream deterministic diff input for enrichment targets
- use the normalized manifest/report shape already established in `cli_extension_v2`

## Success conditions

A realization run is successful only if:
- all required state and enrichment artifacts are emitted
- manifest update obligations are satisfied
- there are no unresolved required semantic roles
- there are no adapter-family mismatches
- deterministic replay produces identical outputs

## Out of scope

This contract does not define:
- `gix` invocation internals
- `sem` enrichment internals
- hydration notebook generation

Those belong to adapter slices, not the realization boundary itself.
