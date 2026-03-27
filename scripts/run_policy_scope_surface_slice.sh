#!/usr/bin/env bash

set -euo pipefail

control_id="policy-scope-surface-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/policy-scope-surface-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
kernel_scope="policy/kernel/scope.index.json"
admission_scope="policy/admission/scope.index.json"
data_scope="policy/data/scope.index.json"
exported_schema="schemas/exported/policy-scope-surface-slice-input.schema.json"
policy_bundle="policy/admission/policy-scope-surface-slice.cue"
render_template="render/jsonnet/registry/policy-scope-surfaces.jsonnet"
rendered_registry="generated/registries/policy-scope-surfaces.index.json"

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

scope_source_schema="$(mktemp)"
jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["scope", "status", "allowed_content", "excluded_content"],
  "properties": {
    "scope": {"type": "string", "enum": ["kernel", "admission", "data"]},
    "status": {"type": "string", "enum": ["placeholder_only", "structural_only"]},
    "allowed_content": {"type": "array", "items": {"type": "string"}},
    "excluded_content": {"type": "array", "items": {"type": "string"}},
    "derived_from": {"type": "array", "items": {"type": "string"}},
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${scope_source_schema}"

g1_module_json="$(mktemp)"
g1_scopes_json="$(mktemp)"
if check-jsonschema --schemafile "${repo_root}/${source_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_module_json}" \
  && check-jsonschema --schemafile "${scope_source_schema}" --output-format json "${repo_root}/${kernel_scope}" "${repo_root}/${admission_scope}" "${repo_root}/${data_scope}" >"${g1_scopes_json}"; then
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
  --slurpfile module_tool_output "${g1_module_json}" \
  --slurpfile scope_tool_output "${g1_scopes_json}" \
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
    tool_output: {
      source_module: $module_tool_output[0],
      policy_scopes: $scope_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${scope_source_schema}" "${g1_module_json}" "${g1_scopes_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "policy-scope-surface-slice-input.schema.json",
  "title": "Policy scope surface slice input",
  "description": "Derived boundary contract for the policy-scope surface slice.",
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
    "scopes",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.policy_scope_surface.slice_input"},
    "control_object_id": {"const": "policy-scope-surface-slice"},
    "source_module_id": {"const": "policy-scope-surface-slice"},
    "source_module_ref": {"const": "structures/core/policy-scope-surface-slice.module.json"},
    "export_schema_ref": {"const": "schemas/exported/policy-scope-surface-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/policy-scope-surface-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/policy-scope-surface-slice.projection.json"},
    "output_path": {"const": "generated/registries/policy-scope-surfaces.index.json"},
    "scopes": {
      "type": "array",
      "minItems": 3,
      "items": {
        "type": "object",
        "required": ["scope", "status", "summary", "allowed_content", "excluded_content", "supporting_refs"],
        "properties": {
          "scope": {"type": "string", "enum": ["kernel", "admission", "data"]},
          "status": {"type": "string", "enum": ["placeholder_only", "structural_only"]},
          "summary": {"type": "string"},
          "allowed_content": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "excluded_content": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "derived_from": {"type": "array", "items": {"type": "string"}},
          "supporting_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1}
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

jq -n \
  --slurpfile kernel "${repo_root}/${kernel_scope}" \
  --slurpfile admission "${repo_root}/${admission_scope}" \
  --slurpfile data "${repo_root}/${data_scope}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.policy_scope_surface.slice_input",
    control_object_id: "policy-scope-surface-slice",
    source_module_id: "policy-scope-surface-slice",
    source_module_ref: "structures/core/policy-scope-surface-slice.module.json",
    export_schema_ref: "schemas/exported/policy-scope-surface-slice-input.schema.json",
    generator_ref: "manifests/generators/policy-scope-surface-slice.generator.json",
    projection_ref: "manifests/projections/policy-scope-surface-slice.projection.json",
    output_path: "generated/registries/policy-scope-surfaces.index.json",
    scopes: [
      {
        scope: $kernel[0].scope,
        status: $kernel[0].status,
        summary: "Kernel structural policy scope for authority and invariant declarations.",
        allowed_content: $kernel[0].allowed_content,
        excluded_content: $kernel[0].excluded_content,
        derived_from: $kernel[0].derived_from,
        supporting_refs: ["policy/kernel/scope.index.json", "kernel.spec.json#/planes/policy"]
      },
      {
        scope: $admission[0].scope,
        status: $admission[0].status,
        summary: "Admission policy scope for normalized-state legality bundles and bounded policy declarations.",
        allowed_content: $admission[0].allowed_content,
        excluded_content: $admission[0].excluded_content,
        derived_from: $admission[0].derived_from,
        supporting_refs: ["policy/admission/scope.index.json", "policy/admission/README.md"]
      },
      {
        scope: $data[0].scope,
        status: $data[0].status,
        summary: "Data policy scope for admitted-state assumptions and static data family declarations.",
        allowed_content: $data[0].allowed_content,
        excluded_content: $data[0].excluded_content,
        derived_from: $data[0].derived_from,
        supporting_refs: ["policy/data/scope.index.json", "policy/data/generated-build-boundary.json"]
      }
    ],
    render_contract: {
      renderer: "jsonnet",
      runtime: "rsjsonnet",
      runtime_path: $runtime_path,
      input_class: "admitted_state",
      output_class: "registry"
    }
  }' >"${repo_root}/$(phase_dir normalization)/normalized-state.json"

check-jsonschema --schemafile "${repo_root}/${exported_schema}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" >/dev/null

jq -n '{
  source_module_ref: "structures/core/policy-scope-surface-slice.module.json",
  field_sources: {
    kernel_scope: ["policy/kernel/scope.index.json"],
    admission_scope: ["policy/admission/scope.index.json"],
    data_scope: ["policy/data/scope.index.json"],
    output_path: ["manifests/projections/policy-scope-surface-slice.projection.json"]
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
      "bound kernel, admission, and data structural policy scopes into one normalized registry input",
      "preserved each scope status without inventing runtime semantics",
      "recorded repo-relative supporting refs for each scope"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/policy-scope-surface-slice.cue",
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
        ref: "schemas/exported/policy-scope-surface-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/policy-scope-surfaces.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/policy-scope-surfaces.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/policy-scope-surfaces.index.json"

cmp -s "${tmp_dir}/generated/registries/policy-scope-surfaces.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered policy-scope registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
