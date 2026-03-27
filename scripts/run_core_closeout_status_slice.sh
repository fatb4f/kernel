#!/usr/bin/env bash

set -euo pipefail

control_id="core-closeout-status-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/core-closeout-status-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
closeout_manifest="manifests/bundles/kernel-core-json-structure-closeout.manifest.json"
exported_schema="schemas/exported/core-closeout-status-slice-input.schema.json"
policy_bundle="policy/admission/core-closeout-status-slice.cue"
render_template="render/jsonnet/reference/core-closeout-status.jsonnet"
rendered_doc="generated/docs/reference/operational-status.md"

jsonnet_bin() {
  if command -v rsjsonnet >/dev/null 2>&1; then
    command -v rsjsonnet
    return
  fi
  if [[ -x "${HOME}/.local/share/cargo/bin/rsjsonnet" ]]; then
    printf '%s\n' "${HOME}/.local/share/cargo/bin/rsjsonnet"
    return
  fi
  printf '%s\n' "rsjsonnet not found" >&2
  exit 1
}

phase_dir() {
  printf '%s/%s/%s\n' "generated/state/$1" "${control_id}" "${run_id}"
}

mkdir -p "${repo_root}/$(phase_dir source-validation)"
mkdir -p "${repo_root}/$(phase_dir export)"
mkdir -p "${repo_root}/$(phase_dir normalization)"
mkdir -p "${repo_root}/$(phase_dir admission)"
mkdir -p "${repo_root}/$(phase_dir render)"
mkdir -p "${repo_root}/$(phase_dir integrity)"

g1_json="$(mktemp)"
if check-jsonschema --schemafile "${repo_root}/${source_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_json}"; then
  g1_status="PASS"
  g1_reasons='[]'
else
  g1_status="FAIL"
  g1_reasons='["SRC_SCHEMA_VALIDATION_FAILED"]'
fi

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg status "${g1_status}" \
  --arg schema_ref "${source_schema}" \
  --arg instance_ref "${source_module}" \
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile tool_output "${g1_json}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    schema_ref: $schema_ref,
    instance_ref: $instance_ref,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema",
    tool_output: $tool_output[0]
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${g1_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "core-closeout-status-slice-input.schema.json",
  "title": "Core closeout status slice input",
  "description": "Derived boundary contract for the operational status page slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "source_module_id",
    "source_module_ref",
    "closeout_manifest_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "current_status",
    "decision_basis",
    "blockers",
    "implemented_slices",
    "status_explanation",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.core_closeout_status.slice_input"},
    "control_object_id": {"const": "core-closeout-status-slice"},
    "source_module_id": {"const": "core-closeout-status-slice"},
    "source_module_ref": {"const": "structures/core/core-closeout-status-slice.module.json"},
    "closeout_manifest_ref": {"const": "manifests/bundles/kernel-core-json-structure-closeout.manifest.json"},
    "export_schema_ref": {"const": "schemas/exported/core-closeout-status-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/core-closeout-status-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/core-closeout-status-slice.projection.json"},
    "output_path": {"const": "generated/docs/reference/operational-status.md"},
    "current_status": {"type": "string", "enum": ["BLOCKED", "OPEN", "DONE", "INVALID"]},
    "decision_basis": {"type": "array", "items": {"type": "string"}},
    "blockers": {"type": "array", "items": {"type": "string"}},
    "implemented_slices": {"type": "array", "items": {"type": "string"}},
    "status_explanation": {"type": "string"},
    "render_contract": {
      "type": "object",
      "required": ["renderer", "runtime", "runtime_path", "input_class", "output_class"],
      "properties": {
        "renderer": {"const": "jsonnet"},
        "runtime": {"type": "string"},
        "runtime_path": {"type": "string"},
        "input_class": {"const": "admitted_state"},
        "output_class": {"const": "documentation"}
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}' >"${repo_root}/${exported_schema}"

g2_json="$(mktemp)"
if check-jsonschema --check-metaschema --output-format json "${repo_root}/${exported_schema}" >"${g2_json}"; then
  g2_status="PASS"
  g2_reasons='[]'
else
  g2_status="FAIL"
  g2_reasons='["EXPORT_SCHEMA_INVALID"]'
fi

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg status "${g2_status}" \
  --arg source_ref "${source_module}" \
  --arg schema_ref "${exported_schema}" \
  --arg exported_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile tool_output "${g2_json}" \
  --argjson reason_codes "${g2_reasons}" \
  '{
    gate: "G2",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    source_ref: $source_ref,
    schema_ref: $schema_ref,
    exported_at: $exported_at,
    reason_codes: $reason_codes,
    tool: "jq + check-jsonschema",
    tool_output: $tool_output[0]
  }' >"${repo_root}/$(phase_dir export)/export-report.json"

rm -f "${g2_json}"
[[ "${g2_status}" == "PASS" ]]

jsonnet_runtime="$(jsonnet_bin)"

jq -n \
  --slurpfile manifest "${repo_root}/${closeout_manifest}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.core_closeout_status.slice_input",
    control_object_id: "core-closeout-status-slice",
    source_module_id: "core-closeout-status-slice",
    source_module_ref: "structures/core/core-closeout-status-slice.module.json",
    closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json",
    export_schema_ref: "schemas/exported/core-closeout-status-slice-input.schema.json",
    generator_ref: "manifests/generators/core-closeout-status-slice.generator.json",
    projection_ref: "manifests/projections/core-closeout-status-slice.projection.json",
    output_path: "generated/docs/reference/operational-status.md",
    current_status: $manifest[0].operational_status_gate.current_status,
    decision_basis: $manifest[0].operational_status_gate.decision_basis,
    blockers: $manifest[0].operational_status_gate.blockers,
    implemented_slices: [
      "reference-docs-executable-slice: G1-G6 evidence is committed",
      "local Jsonnet runtime is available via rsjsonnet"
    ],
    status_explanation: (
      "The core closeout target remains blocked, but the Jsonnet runtime blocker is resolved and one bounded executable slice is now materialized."
    ),
    render_contract: {
      renderer: "jsonnet",
      runtime: "rsjsonnet",
      runtime_path: $runtime_path,
      input_class: "admitted_state",
      output_class: "documentation"
    }
  }' >"${repo_root}/$(phase_dir normalization)/normalized-state.json"

check-jsonschema --schemafile "${repo_root}/${exported_schema}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" >/dev/null

jq -n \
  '{
    source_module_ref: "structures/core/core-closeout-status-slice.module.json",
    closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json",
    field_sources: {
      current_status: ["manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/operational_status_gate/current_status"],
      blockers: ["manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/operational_status_gate/blockers"],
      decision_basis: ["manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/operational_status_gate/decision_basis"]
    }
  }' >"${repo_root}/$(phase_dir normalization)/source-map.json"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg normalized_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    gate: "G3",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    normalized_at: $normalized_at,
    operations: [
      "copied current_status, blockers, and decision_basis from the closeout manifest",
      "bound the operational status page output path",
      "recorded implemented executable slices"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/core-closeout-status-slice.cue",
      admitted_at: $admitted_at
    }
  }' "${repo_root}/$(phase_dir normalization)/normalized-state.json" >"${repo_root}/$(phase_dir admission)/admitted-state.json"

jq -n '[]' >"${repo_root}/$(phase_dir admission)/violations.json"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg policy_bundle_id "${policy_bundle}" \
  --arg decision_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg cue_version "$(cue version | head -n1)" \
  --arg jq_version "$(jq --version)" \
  --arg normalized_digest "$(sha256sum "${repo_root}/$(phase_dir normalization)/normalized-state.json" | awk '{print $1}')" \
  --arg schema_digest "$(sha256sum "${repo_root}/${exported_schema}" | awk '{print $1}')" \
  --arg normalized_ref "generated/state/normalization/${control_id}/${run_id}/normalized-state.json" \
  '{
    decision: "ALLOW",
    control_object_id: $control_object_id,
    run_id: $run_id,
    policy_bundle_id: $policy_bundle_id,
    input_digests: {
      normalized_state: {
        ref: $normalized_ref,
        algorithm: "sha256",
        value: $normalized_digest
      },
      exported_schema: {
        ref: "schemas/exported/core-closeout-status-slice-input.schema.json",
        algorithm: "sha256",
        value: $schema_digest
      }
    },
    tool_versions: {
      cue: $cue_version,
      jq: $jq_version
    },
    issued_at: $decision_at
  }' >"${repo_root}/$(phase_dir admission)/decision.json"

"${jsonnet_runtime}" \
  --string \
  --output-file "${repo_root}/${rendered_doc}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg runtime_path "${jsonnet_runtime}" \
  --arg rendered_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg admitted_state_ref "generated/state/admission/${control_id}/${run_id}/admitted-state.json" \
  '{
    gate: "G5",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    renderer: "jsonnet",
    runtime: "rsjsonnet",
    runtime_path: $runtime_path,
    template_ref: "render/jsonnet/reference/core-closeout-status.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/docs/reference/operational-status.md"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/docs/reference"
cp "${repo_root}/${exported_schema}" "${tmp_dir}/core-closeout-status-slice-input.schema.json"

"${jsonnet_runtime}" \
  --string \
  --output-file "${tmp_dir}/generated/docs/reference/operational-status.md" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}"

cmp -s "${tmp_dir}/generated/docs/reference/operational-status.md" "${repo_root}/${rendered_doc}"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    gate: "G6",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    checked_at: $checked_at,
    checks: [
      "exported schema is present",
      "rendered operational status page regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
