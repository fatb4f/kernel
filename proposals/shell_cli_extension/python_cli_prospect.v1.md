# Python CLI Prospect Against Current Shell/CLI Extension Profile

This prospect evaluates whether the current shell/CLI extension profile can support future Python CLI apps without introducing a parallel authority model.

## Bottom Line

The current profile is structurally close to a general CLI profile.

It is sufficient as a first base for Python CLI work if we:
- keep the canonical metadata model as authority
- preserve CLI semantics in the extension layer
- split implementation adapters by runtime family

It is not yet cleanly future-proof because it still hard-codes shell-specific naming and shell-specific backend assumptions.

## What Already Generalizes Well

These semantic roles are already broad enough for both shell and Python CLIs:
- `command_surface`
- `parameter_surface`
- `environment_binding`
- `dependency_requirement`
- `usage_example`
- `output_contract`
- `verification_expectation`

These are CLI concerns, not shell-only concerns.

The current relation profile also generalizes cleanly:
- `contains`
- `defines`
- `supports`
- `projects_to`
- `references`

That means the current profile is a good candidate for a broader CLI authority profile.

## What Is Still Shell-Specific

The current profile still carries shell-specific assumptions in four places.

### 1. Naming

The current role key is `shell_cli_role`.

That is too narrow if the profile is expected to cover Python CLIs.

Better future naming:
- `cli_role`
- or `command_interface_role`

### 2. Lineage wording

The lineage currently says:
- `shell_assets_remain_projection_only`

That should become something like:
- `implementation_assets_remain_projection_only`
- or `cli_runtime_assets_remain_projection_only`

### 3. Projection backends

The current implementation targets are shell-only:
- `bashly`
- `argc`
- `argbash`

That is correct for the first slice, but not for a generalized CLI future.

### 4. Verification examples

The current verification targets are shell-oriented:
- `bats`
- `shellspec`

Those should remain valid as shell verification consumers, but they are not enough for Python CLIs.

## Recommended Future Shape

Do not replace the current extension profile.

Refactor it into:

1. **core CLI semantic profile**
- command, parameters, env, dependencies, examples, output contract, verification expectations

2. **runtime-specific adapter families**
- shell implementation adapters
- Python implementation adapters
- shell verification adapters
- Python verification adapters

That preserves one authority model and many projection targets.

## Python CLI Implications

### Good fit under the current semantic roles

Python CLI frameworks usually still need:
- command tree
- parameters
- environment bindings
- examples
- output contracts
- verification expectations

So the semantic layer is mostly reusable.

### Likely new Python adapter targets

Probable implementation adapters:
- `argparse`
- `click`
- `typer`
- `jsonargparse`

Probable verification adapters:
- `pytest`
- or CLI black-box runners under `pytest`

These should be modeled as projection targets or consumers, not authority.

### Marimo is not a Python CLI adapter

`marimo` should stay classified as:
- hydration surface
- inspection surface
- derivation surface

It may consume deterministic wrapper outputs or CLI artifacts, but it should not be treated as the canonical Python CLI implementation backend by default.

## Gaps To Address Before Widening

### 1. Rename the role namespace

Current:
- `shell_cli_role`

Recommended future direction:
- `cli_role`

### 2. Separate runtime-neutral semantics from runtime-specific adapters

The current profile mixes:
- CLI semantics
- shell implementation backends

Those should be split more cleanly.

### 3. Add adapter-specific handler semantics

Python CLIs will likely need adapter-side projection fields such as:
- module path
- callable/import target
- packaging entrypoint
- type coercion strategy

These should stay adapter-side where possible, not become core authority fields unless multiple runtimes truly need them.

### 4. Revisit verification target kind

The current profile still uses `canonical_target_kind = other` for verification targets.

That is workable for now, but it is weak if we expect both shell and Python verification families.

## Current recommended first Python adapter target

`jsonargparse` is the strongest current first target because it already combines:
- parser and subcommand structure
- config-file support
- environment parsing
- nested namespaces
- type-hint-aware validation

The companion machine-readable adapter artifact is:
- `jsonargparse_projection_matrix.v1.json`

## Recommended Decision

Use the current extension profile as:
- the first bounded shell/CLI slice

Do not treat it as the final generalized CLI profile yet.

Next normalization step for future Python CLI apps:

1. preserve the current profile and slice
2. define a follow-on refactor from `shell_cli_role` to a broader `cli_role`
3. split projection targets into runtime families:
   - shell implementation
   - Python implementation
   - shell verification
   - Python verification

That avoids breaking the current amendment slice while keeping the path open for Python CLI growth.

## Practical Reading

Current status:
- good enough for shell-first amendment work
- not yet the final runtime-neutral CLI abstraction

Prospect verdict:
- **extendable**
- **not yet fully normalized for Python CLI futures**
