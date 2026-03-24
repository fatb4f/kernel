# Manifest Control Surface

This is the only active manifest control surface for the corrected kernel skeleton.

## Active target classes

- `bundles/` — control objects that declare bundle composition and bundle-class boundaries.
- `projections/` — control objects that declare projection families and projection output classes.
- `generators/` — control objects that declare generator families and generator-facing control inputs.

## Explicit exclusions for this tranche

The following stay outside the active `manifests/` surface in `pkt-r06-04`:

- provider-specific compatibility freezes such as the legacy OpenAI contract manifest
- Cargo manifests and Rust crate metadata
- workspace TOML records carrying manifest pointers
- runtime/tooling orchestration semantics

## Ambiguity closure

- Active target surface: `manifests/`
- No active top-level `manifest/` surface is allowed.
- Cargo/TOML manifest files are not kernel manifest control objects.
