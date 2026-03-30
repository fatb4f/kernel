# `__kernel.git__`

## Scope

This namespace is the first authored module namespace for the kernel Git substrate lane.

It is intentionally narrow:
- packet admission
- packet realization
- packet closeout
- gix fact capture
- sem semantic enrichment
- runtime state recording

It does not attempt a full repo-wide module migration.

## Draft Structure

Authored control surfaces:
- `control/modules/__kernel.git__/inventory.v1.json`
- `control/modules/__kernel.git__/namespace.contract.v1.json`
- `control/scm.pattern/*`

Current operator entrypoints mapped into the namespace:
- `scripts/run_chatgpt_packet_file.py` -> `__kernel.git__.packet.admit`
- `scripts/realize_git_substrate_packet.py` -> `__kernel.git__.packet.realize`
- `scripts/close_git_substrate_packet.py` -> `__kernel.git__.packet.closeout`

External adapter basis mapped into the namespace:
- `codex_home/.../emit_gix_runtime.py` -> `__kernel.git__.adapter.gix`
- `codex_home/.../emit_sem_runtime.py` -> `__kernel.git__.adapter.sem`
- `codex_home/.../control_realize_git_substrate_adapters_v1.py` -> `__kernel.git__.adapter.runner`

Generated runtime state mapped into the namespace, but not authored:
- `generated/state/admission/...` -> `__kernel.git__.state.admission`
- `generated/state/realization/...` -> `__kernel.git__.state.realization`
- `generated/state/closeout/...` -> `__kernel.git__.state.closeout`

## Intended Follow-on Move

Once the namespace is accepted as stable, implementation should move from script-centric naming to module-centric naming.

Target shape:
- thin operator entrypoints in `scripts/`
- reusable implementation under `control/modules/__kernel.git__/...`
- packet and generated state left where they already belong

## Done Condition

The namespace work for this tranche is considered done when:
- the current kernel Git-substrate architecture is inventoried
- one namespace id is explicit: `__kernel.git__`
- the authored/operator/adapter/runtime surfaces are classified under that namespace
- future Git-substrate work can be attached to namespace surfaces instead of discovering loose scripts
