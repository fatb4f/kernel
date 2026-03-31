# OpenAI Structured Output Minimal Contract v1

## Purpose

This document defines the minimum contract surface required to use OpenAI Structured Outputs without allowing schema drift, model drift, or transport ambiguity.

It is a requirements stub.
It does not define runtime implementation.

## Scope

Applies to kernel-owned contract families projected into OpenAI schema-bound responses, starting with:

- `state.v1`
- `session.v1`
- `output.v1`

## Minimal Requirements

### 1. Schema Projection

Each kernel schema used with OpenAI Structured Outputs must have an OpenAI-safe projection.

Required:

- stable schema name
- stable schema version
- explicit projection from kernel schema to OpenAI-safe schema
- `strict: true`

Do not send raw kernel JSON Schema directly unless it is already known to fit the OpenAI-supported subset.

### 2. Model Profile

Structured-output calls must use a pinned model profile.

Required:

- model identifier
- transport identifier
- compatibility note for structured outputs

Do not allow unpinned model substitution on schema-bound paths.

### 3. Request Wrapper

Every structured-output call must declare:

- projected schema name
- projected schema version
- strictness
- model profile
- timeout and retry policy

Keep this separate from the semantic payload schema.

### 4. Failure Policy

The contract must define handling for:

- refusal
- incomplete output
- validation failure
- transport failure

Each case must resolve to explicit behavior:

- retry
- fail closed
- fallback

### 5. Post-Validation

All model outputs must be validated after receipt against the projected schema.

Transport success is not contract success.

### 6. Fixtures

Maintain golden fixtures for:

- one valid `state.v1` response
- one valid `session.v1` response
- one valid `output.v1` response
- one refusal case
- one incomplete-output case

### 7. Emission Policy

Line-oriented formats remain an emission policy above the canonical object model.

Supported policy values may include:

- `json`
- `ndjson`
- `jsonl`

These do not replace the canonical semantic schema.

### 8. Versioning Rule

Every OpenAI structured-output surface must define:

- schema name
- schema version
- change policy

No silent schema mutation is allowed.

## Minimal Artifact Set

The minimum follow-on artifacts are:

- `openai.structured_output.binding.v1.json`
- `openai.structured_output.schema_projection.v1.json`
- `openai.structured_output.failure_policy.v1.json`
- `openai.structured_output.model_profile.v1.json`
- `fixtures/openai_structured_outputs/*.json`

## Boundary Rule

Kernel owns:

- semantic schema meaning
- projection rules
- failure semantics
- versioning

Codex_home owns:

- API invocation
- retry implementation
- transport plumbing
- runtime validation wiring
