# `git`

## Scope

This module root is the first authored kernel module root for the Git substrate lane.

It is intentionally narrow:
- interface envelopes for packet admission, realization, and closeout
- derived execution state for admission, realization, and closeout
- evidence streams tied to authority manifests
- state interfaces backed by `gix` and `sem`

It does not attempt a full repo-wide module migration.

## Canonical Surface Names

Interface envelopes:
- `packet.admit`
- `packet.realize`
- `packet.closeout`
- `packet.contract`

Derived exec state:
- `state.admission`
- `state.realization`
- `state.closeout`

Evidence streams:
- `evidence.authority.manifest`

State interfaces:
- `state/interface.gix`
- `state/interface.sem`

## Draft Structure

Authored control surfaces:
- `control/modules/git/inventory.v1.json`
- `control/modules/git/namespace.contract.v1.json`
- `control/modules/git/structure.v1.md`

Current operator entrypoints mapped into the module root:
- `scripts/run_chatgpt_packet_file.py` -> `packet.admit`
- `scripts/realize_git_substrate_packet.py` -> `packet.realize`
- `scripts/close_git_substrate_packet.py` -> `packet.closeout`

External adapter basis mapped into the module root:
- `codex_home/.../emit_gix_runtime.py` -> `state/interface.gix`
- `codex_home/.../emit_sem_runtime.py` -> `state/interface.sem`
- `codex_home/.../control_realize_git_substrate_adapters_v1.py` -> `generator.interface.runtime`

Generated runtime state mapped into the module root, but not authored:
- `generated/state/admission/...` -> `state.admission`
- `generated/state/realization/...` -> `state.realization`
- `generated/state/closeout/...` -> `state.closeout`

## Naming Rule

- module path provides the domain root: `control/modules/git`
- internal names use kernel-class-aligned surfaces
- `state/interface.*` is used where Git is an interface over state space, not the ontology itself
- packet/state/evidence names are not prefixed with `git` because the module root already carries that domain context

## Done Condition

The namespace work for this tranche is considered done when:
- the current kernel Git-substrate architecture is inventoried
- one canonical module root is explicit: `control/modules/git`
- the authored/operator/adapter/runtime surfaces are classified under canonical names
- future Git-substrate work can be attached to these canonical surfaces instead of discovering loose scripts
