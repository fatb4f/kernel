# Bashly Minimal Target Contract

This contract wires the first concrete Bashly implementation target to the upstream `examples/minimal` shape.

It is the first bounded Bashly realization slice under the CLI extension v2 proposal.

## Purpose

Use the smallest Bashly project source tree that still proves:
- canonical CLI semantics can project into Bashly source surfaces
- behavior can project into a root partial
- `bashly generate` remains a distinct downstream build step

## Required emitted source surfaces

The first Bashly slice emits exactly:
- `src/bashly.yml`
- `src/root_command.sh`

It does not require:
- `settings.yml`
- `bashly-strings.yml`
- subcommand partials
- shared libraries

## Semantic coverage

This first slice covers:
- root `command_surface`
- positional `parameter_surface`
- flag `parameter_surface`
- `usage_example`
- root behavior partial

## Out of scope

This slice does not yet prove:
- settings-aware output path control
- string overrides
- environment variables
- dependencies
- library partials
- subcommands
- ERB or import preprocessing

## Downstream build rule

After the Bashly source surfaces are emitted, the downstream build step is:

`bashly generate`

Run it from the Bashly project root that contains `src/bashly.yml`.

The generated script is downstream of the emitted Bashly source surfaces and remains non-authoritative.

## Why this target

The `minimal` example is the cleanest first Bashly target because it proves the two-source-surface model without pulling in settings, library, or multi-command complexity.
