# Control Modules

This directory is the draft module-namespace surface for authored control logic.

Rules:
- module namespaces, not script filenames, are the primary architectural units
- operator entrypoints remain thin wrappers over namespaced modules
- generated state stays under `generated/` and is not part of authored module namespaces
- packet artifacts remain workflow inputs/outputs, not module implementations
- namespace grammar is class-first and qualified: `<class>.<domain>...`

Current first domain root:
- `git`

This namespace is intentionally focused on the Git substrate lane first so the repo can prove:
- token-burn reduction through stable module naming
- clearer ownership of runtime logic
- cleaner projection targets for adapter-backed entrypoints

Initial authored layout target:
- `control/modules/git/module.root.v1.json`
- `control/modules/git/inventory.v1.json`
- `control/modules/git/namespace.contract.v1.json`
- `control/modules/git/migration.plan.v1.md`
- `control/modules/git/structure.v1.md`

The implementation move from `scripts/` into namespaced modules is a follow-on step.

Current schema family:
- `schemas/control/module_root.schema.json`
- `schemas/control/module_inventory.schema.json`
- `schemas/control/module_namespace_contract.schema.json`
