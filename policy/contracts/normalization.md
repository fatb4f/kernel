# Normalization Contract

Normalization regularizes raw kernel source material into deterministic state for admission.

## Allowed operations

- resolve imports and references
- canonicalize aliases
- apply declared defaults
- normalize ordering and container shape
- expand declared composition into explicit normalized objects
- preserve provenance links to source modules

## Forbidden operations

- decide legality or admissibility
- invent semantic facts
- silently discard source information unless declared
- resolve semantic conflicts without emitting evidence
- render downstream artifacts

## Required outputs

- `normalized-state.json`
- `source-map.json`
- `normalization-report.json`

This file materializes the normalization contract called for by the kernel spec implementation order.
