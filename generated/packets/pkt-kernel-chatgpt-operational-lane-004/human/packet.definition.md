# Packet Definition — pkt-kernel-chatgpt-operational-lane-004

## Title
Implement native ChatGPT problem_set operational lane

## Summary

The repository now has two supporting surfaces for the ChatGPT pipeline:

- the workflow contracts under `generated/schemas/chatgpt-pipeline/workflow`
- the approved packet schema family materialized as `generated/registries/chatgpt-packet-family.index.json`

It also has a snapshot-style executor under `scripts/execute_chatgpt_pipeline_operational_bundle.py` and an executed admission snapshot for `chatgpt-pipeline-operational-packet`. That is useful evidence, but it is not yet the native repo lane.

## Problem

The remaining gap is the collapsed operational path:

`problem_set` in -> ChatGPT owns packet generation -> local validation and gate evaluation -> realization blocked pending authoritative human review

The current state does not yet provide that native path. The schema family is materialized and the bundle executor proves a snapshot admission path, but the repo still lacks the first-class lane runner that emits packet instances from `problem_set` and evaluates realization readiness locally.

## Goal

Implement the native operational lane with this exact shape:

1. ingest a first-class `problem_set`
2. emit the required packet artifact set under the canonical packet root
3. evaluate local validation, execution policy, and gate policy
4. emit admission evidence in the standard generated state paths
5. block realization until `packet.review.decision.json` exists as the authoritative human review artifact

## Required lane properties

- `problem_set` is the only admissible ingress contract
- packet generation must produce the canonical machine and human artifacts
- schema-family registry evidence is supporting input, not closure
- the snapshot bundle executor is supporting evidence, not the native lane
- realization must remain blocked unless an authoritative review decision exists
- writes must remain bound to `scm.pattern`

## Why this packet exists now

The approved packet family materialization is a real closeout for the schema boundary, but it should not be mistaken for the operational lane itself. This packet isolates that remaining gap so the next implementation slice can target the actual runtime path instead of adding more registry-only layers.

## Expected next implementation slice

- add a native lane runner that accepts `problem_set`
- emit packet instance artifacts into `generated/packets/<packet-id>/`
- validate locally against:
  - `chatgpt.packet.pipeline.manifest.json`
  - `chatgpt.execution.policy.json`
  - `chatgpt.validation.manifest.json`
  - `chatgpt.gate.policy.json`
- stop at `WAITING_HUMAN_REVIEW` unless `packet.review.decision.json` exists

## Out of scope

- redefining the existing packet schema family
- treating the bundle executor as the final runtime shape
- bypassing the human review decision boundary
- allowing realization from packet file presence alone
