#!/usr/bin/env bash

set -euo pipefail

control_id="drift-integrity-surface-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/drift-integrity-surface-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
boundary_ref="policy/data/generated-build-boundary.json"
exported_schema="schemas/exported/drift-integrity-surface-slice-input.schema.json"
policy_bundle="policy/admission/drift-integrity-surface-slice.cue"
render_template="render/jsonnet/registry/drift-integrity-surfaces.jsonnet"
rendered_registry="generated/registries/drift-integrity-surfaces.index.json"

drift_refs=(
  "generated/state/integrity/reference-docs-executable-slice/2026-03-26T23-05-00Z/drift-report.json"
  "generated/state/integrity/core-closeout-status-slice/2026-03-26T23-20-00Z/drift-report.json"
  "generated/state/integrity/boundary-family-registry-slice/2026-03-26T23-40-00Z/drift-report.json"
  "generated/state/integrity/closeout-status-registry-slice/2026-03-26T23-55-00Z/drift-report.json"
  "generated/state/integrity/policy-scope-surface-slice/2026-03-27T00-10-00Z/drift-report.json"
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

g1_module_json="$(mktemp)"
g1_boundary_json="$(mktemp)"
if check-jsonschema --schemafile "${repo_root}/${source_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_module_json}" \
  && jq empty "${repo_root}/${boundary_ref}" >"${g1_boundary_json}"; then
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
  --arg boundary_ref "${boundary_ref}" \
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile module_tool_output "${g1_module_json}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    schema_ref: $schema_ref,
    instance_ref: $instance_ref,
    boundary_ref: $boundary_ref,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema + jq",
    tool_output: {
      source_module: $module_tool_output[0],
      boundary_json_valid: true
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${g1_module_json}" "${g1_boundary_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "drift-integrity-surface-slice-input.schema.json",
  "title": "Drift integrity surface slice input",
  "description": "Derived boundary contract for the drift-integrity surface slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "source_module_id",
    "source_module_ref",
    "boundary_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "generated_classes",
    "build_classes",
    "invariants",
    "drift_runs",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.drift_integrity_surface.slice_input"},
    "control_object_id": {"const": "drift-integrity-surface-slice"},
    "source_module_id": {"const": "drift-integrity-surface-slice"},
    "source_module_ref": {"const": "structures/core/drift-integrity-surface-slice.module.json"},
    "boundary_ref": {"const": "policy/data/generated-build-boundary.json"},
    "export_schema_ref": {"const": "schemas/exported/drift-integrity-surface-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/drift-integrity-surface-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/drift-integrity-surface-slice.projection.json"},
    "output_path": {"const": "generated/registries/drift-integrity-surfaces.index.json"},
    "generated_classes": {"type": "array", "minItems": 1},
    "build_classes": {"type": "array", "minItems": 1},
    "invariants": {"type": "array", "items": {"type": "string"}, "minItems": 1},
    "drift_runs": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["control_object_id", "run_id", "status", "checks"],
        "properties": {
          "control_object_id": {"type": "string"},
          "run_id": {"type": "string"},
          "status": {"type": "string", "enum": ["PASS", "FAIL"]},
          "checks": {"type": "array", "items": {"type": "string"}, "minItems": 1}
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

jq_args=(
  -n
  --slurpfile boundary "${repo_root}/${boundary_ref}"
  --arg runtime_path "${jsonnet_runtime}"
)

for i in "${!drift_refs[@]}"; do
  jq_args+=(--slurpfile "drift${i}" "${repo_root}/${drift_refs[$i]}")
done

jq "${jq_args[@]}" '
  {
    kind: "kernel.drift_integrity_surface.slice_input",
    control_object_id: "drift-integrity-surface-slice",
    source_module_id: "drift-integrity-surface-slice",
    source_module_ref: "structures/core/drift-integrity-surface-slice.module.json",
    boundary_ref: "policy/data/generated-build-boundary.json",
    export_schema_ref: "schemas/exported/drift-integrity-surface-slice-input.schema.json",
    generator_ref: "manifests/generators/drift-integrity-surface-slice.generator.json",
    projection_ref: "manifests/projections/drift-integrity-surface-slice.projection.json",
    output_path: "generated/registries/drift-integrity-surfaces.index.json",
    generated_classes: $boundary[0].generated_classes,
    build_classes: $boundary[0].build_classes,
    invariants: $boundary[0].invariants,
    drift_runs: [
      {
        control_object_id: $drift0[0].control_object_id,
        run_id: $drift0[0].run_id,
        status: $drift0[0].status,
        checks: $drift0[0].checks
      },
      {
        control_object_id: $drift1[0].control_object_id,
        run_id: $drift1[0].run_id,
        status: $drift1[0].status,
        checks: $drift1[0].checks
      },
      {
        control_object_id: $drift2[0].control_object_id,
        run_id: $drift2[0].run_id,
        status: $drift2[0].status,
        checks: $drift2[0].checks
      },
      {
        control_object_id: $drift3[0].control_object_id,
        run_id: $drift3[0].run_id,
        status: $drift3[0].status,
        checks: $drift3[0].checks
      },
      {
        control_object_id: $drift4[0].control_object_id,
        run_id: $drift4[0].run_id,
        status: $drift4[0].status,
        checks: $drift4[0].checks
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
  source_module_ref: "structures/core/drift-integrity-surface-slice.module.json",
  boundary_ref: "policy/data/generated-build-boundary.json",
  field_sources: {
    generated_classes: ["policy/data/generated-build-boundary.json#/generated_classes"],
    build_classes: ["policy/data/generated-build-boundary.json#/build_classes"],
    drift_runs: [
      "generated/state/integrity/reference-docs-executable-slice/2026-03-26T23-05-00Z/drift-report.json",
      "generated/state/integrity/core-closeout-status-slice/2026-03-26T23-20-00Z/drift-report.json",
      "generated/state/integrity/boundary-family-registry-slice/2026-03-26T23-40-00Z/drift-report.json",
      "generated/state/integrity/closeout-status-registry-slice/2026-03-26T23-55-00Z/drift-report.json",
      "generated/state/integrity/policy-scope-surface-slice/2026-03-27T00-10-00Z/drift-report.json"
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
      "bound generated/build authority boundary declarations into one integrity surface input",
      "collected committed drift reports across executed slices",
      "preserved drift checks without introducing new integrity claims"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/drift-integrity-surface-slice.cue",
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
        ref: "schemas/exported/drift-integrity-surface-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/drift-integrity-surfaces.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/drift-integrity-surfaces.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/drift-integrity-surfaces.index.json"

cmp -s "${tmp_dir}/generated/registries/drift-integrity-surfaces.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered integrity registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
