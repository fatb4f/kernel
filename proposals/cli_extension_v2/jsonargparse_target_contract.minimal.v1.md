# jsonargparse Minimal Target Contract

This contract wires the first concrete jsonargparse implementation target to the runtime-neutral CLI v2 semantic example.

It is the first bounded Python implementation slice under the CLI extension v2 proposal.

## Purpose

Use the smallest jsonargparse project source tree that still proves:
- canonical CLI semantics can project into a Python parser module
- environment binding remains present in the Python lane
- minimal verification can project into a pytest source file

## Required emitted source surfaces

The first jsonargparse slice emits:
- `parser.py`
- `test_control_plane_inspect.py`

It does not require:
- packaging metadata
- console entrypoint setup
- config-file persistence helpers
- dataclass or class-based argument enrichment

## Semantic coverage

This first slice covers:
- root `command_surface`
- option `parameter_surface`
- `environment_binding`
- `output_contract` influence on rendered output behavior
- `verification_expectation` projection into pytest source

## Out of scope

This slice does not yet prove:
- packaging or installation
- multi-level subcommands
- dataclass/class/function adapters
- config-file save/load flows
- marimo hydration surfaces

## Downstream verification rule

After the jsonargparse source surfaces are emitted, the downstream verification step is:

`pytest -q test_control_plane_inspect.py`

Run it from the emitted project root that contains `parser.py`.

## Why this target

This is the cleanest first Python target because it keeps the emitted surface small while preserving the key difference from the first Bashly slice: environment binding stays native to the adapter rather than being deferred.
