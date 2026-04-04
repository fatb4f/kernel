# Git Capability Service Workflow DAG

Assumptions for this DAG:
- the post-adapter next steps are already synced
- the operator entrypoint is a `just` module, not a loose script
- `gix` and `sem` are already closed for the first real-runtime tranche

## Architecture DAG

```mermaid
flowchart TD
    A[Canonical Metadata Authority] --> B[Unified Git Realization Runner]
    A --> C[Git Capability Service Policy]
    A --> D[Git Capability Service API Contract]

    E[just Module Entrypoint] --> F[Planner / Higher-Level Controller]
    F --> G[Capability Request Envelope]
    G --> H[Deterministic Policy Engine]

    C --> H
    D --> H

    H -->|R0 allow| I[Capability Executor]
    H -->|R1 sandbox only| I
    H -->|R2 approved| I
    H -->|R3 blocked| J[Denied Decision]

    I --> K[gix Runtime Surface]
    I --> L[sem Runtime Surface]
    K --> M[repo_state.json / diff_state.json]
    L --> N[semantic_diff.json / review_basis.json]

    M --> O[Normalized Manifest / Report]
    N --> O
    I --> P[Intent-Level Audit Stream]
    H --> P
    J --> P

    O --> Q[Script Migration Consumers]
    D --> Q
```

## Workflow DAG

```mermaid
flowchart TD
    A1[just git-capability.<operation>] --> A2[Planner emits task intent]
    A2 --> A3[Build execution envelope]
    A3 --> A4[Policy engine validates repo / branch / path / environment]

    A4 -->|deny| A5[Return structured denial]
    A4 -->|allow| A6[Executor dispatch]

    A6 -->|read-only / structural ops| A7[gix]
    A6 -->|semantic enrichment| A8[sem]
    A6 -->|repo-visible write with approval| A9[gix write path]

    A7 --> A10[Structured Git facts]
    A8 --> A11[Structured semantic diff]
    A9 --> A12[Branch / commit / PR result]

    A10 --> A13[Manifest + report]
    A11 --> A13
    A12 --> A13

    A3 --> A14[Audit record]
    A4 --> A14
    A6 --> A14
    A13 --> A14

    A13 --> A15[Downstream module consumers]
    A15 --> A16[Script migration tranche]
```

## Interpretation

- `just` is the operational entrypoint module.
- Planner output is intent only; it does not carry Git policy.
- Policy is deterministic and external to the model.
- The executor is thin and only dispatches approved task-shaped operations.
- `gix` handles deterministic Git facts.
- `sem` handles semantic enrichment downstream of deterministic diff capture.
- All durable output is structured data plus normalized manifest/report and audit streams.
- Script migration consumes the service contract instead of using raw Git/runtime surfaces directly.
