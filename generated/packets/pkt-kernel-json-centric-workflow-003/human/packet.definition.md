# Packet Definition — pkt-kernel-json-centric-workflow-003

## Title
Implement executable JSON-centric kernel workflow

## Summary

The repo now has a normative kernel spec in both prose and JSON that fixes the authority model, four-state pipeline, repo semantics, gates, and admission-artifact conventions, while the README still describes the repository as a structural baseline that does **not** yet implement normalize/admit/render or controller/runtime logic. It also now includes Jsonnet-oriented reference-doc manifests/docs plus a closeout checklist manifest, but the current operational status is explicitly recorded as `BLOCKED` because the local Jsonnet CLI/runtime is unavailable.

## Problem

The repository contains the right architecture and normative spec, but it is still a structural baseline. The kernel spec already defines the intended execution model:

- canonical structural model = authority
- JSON Structure = authoring syntax
- JSON Schema = derived/exported contract
- CUE = admission over normalized state
- Jsonnet = rendering over admitted state
- raw sources flow through `raw sources -> normalized state -> admitted state -> rendered artifacts`

This packet preserves the original issue draft as a kernel packet artifact. The goal is to turn the current structural/spec baseline into an executable, deterministic, JSON-centric workflow that actually runs the full lane end to end.

## Goal

Implement the first fully executable kernel workflow with this exact shape:

1. JSON Structure remains the human-authored, canonical source plane.
2. JSON Schema is generated from JSON Structure and treated as a derived/exported boundary contract.
3. Normalization produces a deterministic normalized-state package.
4. CUE evaluates admissibility over normalized state and emits the required decision artifacts.
5. Jsonnet projects from admitted state only into generated docs, registries, and other downstream artifacts.
6. The whole path is regen-clean, fail-closed, and wired to the repo’s existing gate model.

## Why this exact direction

The repository’s own authority model already says JSON Structure is the authoring syntax, JSON Schema is derived, CUE is admission, and Jsonnet is rendering. So the missing implementation should follow that model directly instead of inventing a new one.

## Proposed workflow

### Source / authority plane

- JSON Structure sources under `structures/`
- manifest control objects under `manifests/`

### Contract / validation plane

- JSON Schema export under `schemas/exported/`
- schema validation for exported contracts

### Admission plane

- normalization to deterministic JSON state
- CUE admission over normalized state only
- required decision artifacts under `generated/state/admission/<control-object-id>/<run-id>/`

### Projection plane

- Jsonnet renderers under `render/jsonnet/`
- generated downstream artifacts under `generated/`

## Required repository additions

- canonical source documents under `structures/`
- derived boundary contracts under `schemas/exported/`
- CUE admission bundle under `policy/admission/`
- Jsonnet projectors under `render/jsonnet/`
- control manifests under `manifests/generators/`, `manifests/projections/`, and `manifests/bundles/`

## Definition of done

- authoritative source files exist under `structures/`
- exported JSON Schemas are derived, committed, and regen-clean
- normalization emits required artifacts deterministically
- CUE admission emits required admission artifacts
- Jsonnet renders committed downstream outputs from admitted state only
- the blocked render-lane status is cleared by making Jsonnet executable in the local/CI toolchain
- drift checks fail closed on unapproved diffs or hand-edited derived files

## Out of scope

- replacing JSON Structure with CUE as the source authority
- hand-authoring exported JSON Schema
- allowing Jsonnet to read raw authoring sources directly
- collapsing normalization and admission into one opaque step
- treating compatibility shims as authority
