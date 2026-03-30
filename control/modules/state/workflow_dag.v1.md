# State-First Workflow DAG

## North Star

The primary interface is a state service:
- `get_state`
- `hydrate_state`

The operator entrypoint is a `just` module.
`just` wraps Python, Python wraps `gix` and `sem`, and structured output crosses ACP into the Marimo registry/view layer.

## Architecture DAG

```mermaid
flowchart TD
    A[Operator] --> B[just module]
    B --> C[Python state wrapper]

    C --> D[get_state]
    C --> E[hydrate_state]

    D --> F[gix substrate adapter]
    E --> F
    E --> G[sem enrichment adapter]

    F --> H[repo_state + diff_state]
    G --> I[semantic_state + review_basis]

    H --> J[unified state envelope]
    I --> J

    J --> K[ACP response envelope]
    K --> L[Marimo registry]
    L --> M[hydrated views]
```

## Workflow DAG

```mermaid
flowchart TD
    A1[just state.get] --> A2[Python wrapper validates request]
    A2 --> A3[gix get_state]
    A3 --> A4[normalize unified state snapshot]
    A4 --> A5[ACP structured response]
    A5 --> A6[Marimo registry registers snapshot]

    B1[just state.hydrate] --> B2[Python wrapper validates request]
    B2 --> B3[load prior snapshot or request fresh substrate read]
    B3 --> B4[gix refresh deterministic state]
    B4 --> B5[sem enrich semantic state]
    B5 --> B6[normalize hydrated snapshot]
    B6 --> B7[ACP structured response]
    B7 --> B8[Marimo registry updates hydration state]
```

## Operational Rules

- `get_state` is side-effect free and idempotent.
- `hydrate_state` refreshes and enriches snapshots; it does not write to the repo.
- ACP carries transport metadata and structured payloads only.
- Marimo owns snapshot registration, indexing, hydration lifecycle, and views.
- `gix` remains the deterministic Git fact source.
- `sem` remains downstream enrichment over deterministic diff input.
