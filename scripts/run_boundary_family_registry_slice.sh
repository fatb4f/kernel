#!/usr/bin/env bash

set -euo pipefail

control_id="boundary-family-registry-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/boundary-family-registry-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
policy_scope_ref="policy/admission/scope.index.json"
policy_scope_schema="schemas/exported/policy-scope-index-family.schema.json"
exported_schema="schemas/exported/boundary-family-registry-slice-input.schema.json"
policy_bundle="policy/admission/boundary-family-registry-slice.cue"
render_template="render/jsonnet/registry/boundary-family-registry.jsonnet"
rendered_registry="generated/registries/boundary-families.index.json"

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

g1_source_json="$(mktemp)"
g1_scope_json="$(mktemp)"
if check-jsonschema \
  --schemafile "${repo_root}/${source_schema}" \
  --output-format json \
  "${repo_root}/${source_module}" >"${g1_source_json}" \
  && check-jsonschema \
    --schemafile "${repo_root}/${policy_scope_schema}" \
    --output-format json \
    "${repo_root}/${policy_scope_ref}" >"${g1_scope_json}"; then
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
  --arg source_schema_ref "${source_schema}" \
  --arg policy_scope_schema_ref "${policy_scope_schema}" \
  --arg source_ref "${source_module}" \
  --arg policy_scope_ref "${policy_scope_ref}" \
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile source_tool_output "${g1_source_json}" \
  --slurpfile scope_tool_output "${g1_scope_json}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    source_schema_ref: $source_schema_ref,
    policy_scope_schema_ref: $policy_scope_schema_ref,
    source_ref: $source_ref,
    policy_scope_ref: $policy_scope_ref,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema",
    tool_output: {
      source_module: $source_tool_output[0],
      policy_scope: $scope_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${g1_source_json}" "${g1_scope_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "boundary-family-registry-slice-input.schema.json",
  "title": "Boundary family registry slice input",
  "description": "Derived boundary contract for the boundary-family registry slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "registry_id",
    "source_module_id",
    "source_module_ref",
    "policy_scope_ref",
    "policy_scope_status",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "entries",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.boundary_family_registry.slice_input"},
    "control_object_id": {"const": "boundary-family-registry-slice"},
    "registry_id": {"const": "kernel-boundary-families"},
    "source_module_id": {"const": "boundary-family-registry-slice"},
    "source_module_ref": {"const": "structures/core/boundary-family-registry-slice.module.json"},
    "policy_scope_ref": {"const": "policy/admission/scope.index.json"},
    "policy_scope_status": {"type": "string", "enum": ["placeholder_only", "structural_only"]},
    "export_schema_ref": {"const": "schemas/exported/boundary-family-registry-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/boundary-family-registry-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/boundary-family-registry-slice.projection.json"},
    "output_path": {"const": "generated/registries/boundary-families.index.json"},
    "entries": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": [
          "family",
          "plane",
          "summary",
          "source_refs",
          "derived_contract_ref",
          "evidence_refs",
          "status"
        ],
        "properties": {
          "family": {"type": "string"},
          "plane": {"type": "string", "enum": ["structure", "control", "policy"]},
          "summary": {"type": "string"},
          "source_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "derived_contract_ref": {"type": "string"},
          "evidence_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "status": {"type": "string", "enum": ["materialized", "partial"]}
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
  --slurpfile source "${repo_root}/${source_module}" \
  --slurpfile scope "${repo_root}/${policy_scope_ref}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.boundary_family_registry.slice_input",
    control_object_id: "boundary-family-registry-slice",
    registry_id: "kernel-boundary-families",
    source_module_id: $source[0].id,
    source_module_ref: "structures/core/boundary-family-registry-slice.module.json",
    policy_scope_ref: "policy/admission/scope.index.json",
    policy_scope_status: $scope[0].status,
    export_schema_ref: "schemas/exported/boundary-family-registry-slice-input.schema.json",
    generator_ref: "manifests/generators/boundary-family-registry-slice.generator.json",
    projection_ref: "manifests/projections/boundary-family-registry-slice.projection.json",
    output_path: "generated/registries/boundary-families.index.json",
    entries: [
      $source[0].fragments[] | {
        family: .name,
        plane: (
          if .name == "canonical-structure-family" then "structure"
          elif .name == "manifest-control-family" then "control"
          else "policy"
          end
        ),
        summary: .description,
        source_refs: .source_refs,
        derived_contract_ref: (
          if .name == "canonical-structure-family" then "schemas/exported/canonical-structure-family.schema.json"
          elif .name == "manifest-control-family" then "schemas/exported/manifest-control-family.schema.json"
          else "schemas/exported/policy-scope-index-family.schema.json"
          end
        ),
        evidence_refs: (
          if .name == "canonical-structure-family" then ["structures/core/", "structures/relations/", "structures/extensions/"]
          elif .name == "manifest-control-family" then ["manifests/bundles/", "manifests/projections/", "manifests/generators/"]
          else ["policy/admission/scope.index.json", "policy/admission/"]
          end
        ),
        status: (
          if .name == "policy-scope-index-family" and $scope[0].status == "placeholder_only" then "partial"
          else "materialized"
          end
        )
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

jq -n \
  '{
    source_module_ref: "structures/core/boundary-family-registry-slice.module.json",
    policy_scope_ref: "policy/admission/scope.index.json",
    field_sources: {
      entries: [
        {
          family: "canonical-structure-family",
          refs: [
            "structures/core/boundary-family-registry-slice.module.json#/fragments/0",
            "schemas/exported/canonical-structure-family.schema.json"
          ]
        },
        {
          family: "manifest-control-family",
          refs: [
            "structures/core/boundary-family-registry-slice.module.json#/fragments/1",
            "schemas/exported/manifest-control-family.schema.json"
          ]
        },
        {
          family: "policy-scope-index-family",
          refs: [
            "structures/core/boundary-family-registry-slice.module.json#/fragments/2",
            "schemas/exported/policy-scope-index-family.schema.json",
            "policy/admission/scope.index.json"
          ]
        }
      ],
      output_path: [
        "manifests/projections/boundary-family-registry-slice.projection.json"
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
      "mapped authoritative structural fragments to registry entries",
      "bound derived contracts to each family entry",
      "marked policy-scope family as partial because the current scope index remains structural-only placeholder content"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/boundary-family-registry-slice.cue",
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
        ref: "schemas/exported/boundary-family-registry-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/boundary-family-registry.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/boundary-families.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/boundary-families.index.json"

cmp -s "${tmp_dir}/generated/registries/boundary-families.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
