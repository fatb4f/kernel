#!/usr/bin/env bash

set -euo pipefail

control_id="normalization-surface-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/normalization-surface-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
exported_schema="schemas/exported/normalization-surface-slice-input.schema.json"
policy_bundle="policy/admission/normalization-surface-slice.cue"
render_template="render/jsonnet/registry/normalization-surfaces.jsonnet"
rendered_registry="generated/registries/normalization-surfaces.index.json"

slice_specs=(
  "reference-docs-executable-slice|2026-03-26T23-05-00Z"
  "core-closeout-status-slice|2026-03-26T23-20-00Z"
  "boundary-family-registry-slice|2026-03-26T23-40-00Z"
  "closeout-status-registry-slice|2026-03-26T23-55-00Z"
  "policy-scope-surface-slice|2026-03-27T00-10-00Z"
  "drift-integrity-surface-slice|2026-03-27T00-30-00Z"
)

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

mkdir -p "${repo_root}/generated/registries"
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
  "$id": "normalization-surface-slice-input.schema.json",
  "title": "Normalization surface slice input",
  "description": "Derived boundary contract for the normalization surface slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "source_module_id",
    "source_module_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "slices",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.normalization_surface.slice_input"},
    "control_object_id": {"const": "normalization-surface-slice"},
    "source_module_id": {"const": "normalization-surface-slice"},
    "source_module_ref": {"const": "structures/core/normalization-surface-slice.module.json"},
    "export_schema_ref": {"const": "schemas/exported/normalization-surface-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/normalization-surface-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/normalization-surface-slice.projection.json"},
    "output_path": {"const": "generated/registries/normalization-surfaces.index.json"},
    "slices": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["control_object_id", "run_id", "normalized_state_ref", "source_map_ref", "report_ref", "report_status", "operations"],
        "properties": {
          "control_object_id": {"type": "string"},
          "run_id": {"type": "string"},
          "normalized_state_ref": {"type": "string"},
          "source_map_ref": {"type": "string"},
          "report_ref": {"type": "string"},
          "report_status": {"type": "string", "enum": ["PASS", "FAIL"]},
          "operations": {"type": "array", "items": {"type": "string"}, "minItems": 1}
        },
        "additionalProperties": false
      }
    },
    "render_contract": {
      "type": "object",
      "required": ["renderer", "runtime", "runtime_path", "input_class", "output_class"],
      "properties": {
        "renderer": {"const": "jsonnet"},
        "runtime": {"type": "string"},
        "runtime_path": {"type": "string"},
        "input_class": {"const": "admitted_state"},
        "output_class": {"const": "registry"}
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
slice_entries_json="$(mktemp)"
printf '[]\n' >"${slice_entries_json}"

for spec in "${slice_specs[@]}"; do
  cid="${spec%%|*}"
  rid="${spec##*|}"
  report_path="${repo_root}/generated/state/normalization/${cid}/${rid}/normalization-report.json"
  report_status="$(jq -r '.status' "${report_path}")"
  operations_json="$(jq '.operations' "${report_path}")"
  next_entries_json="$(mktemp)"
  jq \
    --arg cid "${cid}" \
    --arg rid "${rid}" \
    --arg normalized_state_ref "generated/state/normalization/${cid}/${rid}/normalized-state.json" \
    --arg source_map_ref "generated/state/normalization/${cid}/${rid}/source-map.json" \
    --arg report_ref "generated/state/normalization/${cid}/${rid}/normalization-report.json" \
    --arg report_status "${report_status}" \
    --argjson operations "${operations_json}" \
    '. + [{
      control_object_id: $cid,
      run_id: $rid,
      normalized_state_ref: $normalized_state_ref,
      source_map_ref: $source_map_ref,
      report_ref: $report_ref,
      report_status: $report_status,
      operations: $operations
    }]' "${slice_entries_json}" >"${next_entries_json}"
  mv "${next_entries_json}" "${slice_entries_json}"
done

jq -n \
  --arg runtime_path "${jsonnet_runtime}" \
  --slurpfile slices "${slice_entries_json}" \
  '{
    kind: "kernel.normalization_surface.slice_input",
    control_object_id: "normalization-surface-slice",
    source_module_id: "normalization-surface-slice",
    source_module_ref: "structures/core/normalization-surface-slice.module.json",
    export_schema_ref: "schemas/exported/normalization-surface-slice-input.schema.json",
    generator_ref: "manifests/generators/normalization-surface-slice.generator.json",
    projection_ref: "manifests/projections/normalization-surface-slice.projection.json",
    output_path: "generated/registries/normalization-surfaces.index.json",
    slices: $slices[0],
    render_contract: {
      renderer: "jsonnet",
      runtime: "rsjsonnet",
      runtime_path: $runtime_path,
      input_class: "admitted_state",
      output_class: "registry"
    }
  }' >"${repo_root}/$(phase_dir normalization)/normalized-state.json"

rm -f "${slice_entries_json}"

check-jsonschema --schemafile "${repo_root}/${exported_schema}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" >/dev/null

jq -n '{
  source_module_ref: "structures/core/normalization-surface-slice.module.json",
  field_sources: {
    slices: [
      "generated/state/normalization/reference-docs-executable-slice/2026-03-26T23-05-00Z/*",
      "generated/state/normalization/core-closeout-status-slice/2026-03-26T23-20-00Z/*",
      "generated/state/normalization/boundary-family-registry-slice/2026-03-26T23-40-00Z/*",
      "generated/state/normalization/closeout-status-registry-slice/2026-03-26T23-55-00Z/*",
      "generated/state/normalization/policy-scope-surface-slice/2026-03-27T00-10-00Z/*",
      "generated/state/normalization/drift-integrity-surface-slice/2026-03-27T00-30-00Z/*"
    ]
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
      "bound normalized-state, source-map, and normalization-report artifacts across executed slices into one registry input",
      "preserved per-slice normalization operations from committed reports",
      "avoided inventing any new normalized-state semantics"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/normalization-surface-slice.cue",
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
        ref: "schemas/exported/normalization-surface-slice-input.schema.json",
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
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${repo_root}/${rendered_registry}"

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
    template_ref: "render/jsonnet/registry/normalization-surfaces.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/normalization-surfaces.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/normalization-surfaces.index.json"

cmp -s "${tmp_dir}/generated/registries/normalization-surfaces.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered normalization registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
