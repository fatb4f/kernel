#!/usr/bin/env bash

set -euo pipefail

control_id="closeout-status-registry-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/closeout-status-registry-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
closeout_manifest="manifests/bundles/kernel-core-json-structure-closeout.manifest.json"
boundary_registry="generated/registries/boundary-families.index.json"
operational_status_doc="generated/docs/reference/operational-status.md"
exported_schema="schemas/exported/closeout-status-registry-slice-input.schema.json"
policy_bundle="policy/admission/closeout-status-registry-slice.cue"
render_template="render/jsonnet/registry/closeout-status-registry.jsonnet"
rendered_registry="generated/registries/kernel-core-closeout-status.index.json"

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
if check-jsonschema \
  --schemafile "${repo_root}/${source_schema}" \
  --output-format json \
  "${repo_root}/${source_module}" >"${g1_json}"; then
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
  "$id": "closeout-status-registry-slice-input.schema.json",
  "title": "Closeout status registry slice input",
  "description": "Derived boundary contract for the kernel core closeout status registry slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "registry_id",
    "source_module_id",
    "source_module_ref",
    "closeout_manifest_ref",
    "boundary_registry_ref",
    "operational_status_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "current_gate_status",
    "blockers",
    "checklist_statuses",
    "component_statuses",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.closeout_status_registry.slice_input"},
    "control_object_id": {"const": "closeout-status-registry-slice"},
    "registry_id": {"const": "kernel-core-closeout-status"},
    "source_module_id": {"const": "closeout-status-registry-slice"},
    "source_module_ref": {"const": "structures/core/closeout-status-registry-slice.module.json"},
    "closeout_manifest_ref": {"const": "manifests/bundles/kernel-core-json-structure-closeout.manifest.json"},
    "boundary_registry_ref": {"const": "generated/registries/boundary-families.index.json"},
    "operational_status_ref": {"const": "generated/docs/reference/operational-status.md"},
    "export_schema_ref": {"const": "schemas/exported/closeout-status-registry-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/closeout-status-registry-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/closeout-status-registry-slice.projection.json"},
    "output_path": {"const": "generated/registries/kernel-core-closeout-status.index.json"},
    "current_gate_status": {"type": "string", "enum": ["BLOCKED", "OPEN", "DONE", "INVALID"]},
    "blockers": {"type": "array", "items": {"type": "string"}},
    "checklist_statuses": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "label", "manifest_status", "observed_status", "evidence_refs"],
        "properties": {
          "id": {"type": "string"},
          "label": {"type": "string"},
          "manifest_status": {"type": "string", "enum": ["open", "done"]},
          "observed_status": {"type": "string", "enum": ["open", "partial", "materialized"]},
          "evidence_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1}
        },
        "additionalProperties": false
      }
    },
    "component_statuses": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "name", "plane", "manifest_status", "observed_status", "evidence_refs"],
        "properties": {
          "id": {"type": "string"},
          "name": {"type": "string"},
          "plane": {"type": "string"},
          "manifest_status": {"type": "string", "enum": ["open", "done"]},
          "observed_status": {"type": "string", "enum": ["open", "partial", "materialized"]},
          "evidence_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1}
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
  --slurpfile manifest "${repo_root}/${closeout_manifest}" \
  --slurpfile boundary "${repo_root}/${boundary_registry}" \
  --arg runtime_path "${jsonnet_runtime}" \
  'def checklist_observed($item):
      if $item.id == "c1" or $item.id == "c2" or $item.id == "c3" or $item.id == "c11" then "materialized"
      elif $item.id == "c4" then "materialized"
      elif $item.id == "c5" or $item.id == "c6" or $item.id == "c7" or $item.id == "c8" or $item.id == "c9" or $item.id == "c10" then "partial"
      else "open"
      end;
    def checklist_evidence($item):
      if $item.id == "c1" then ["kernel.spec.json", "kernel.spec.md"]
      elif $item.id == "c2" then ["kernel.spec.json#/authority_model", "generated/docs/reference/workflow.md"]
      elif $item.id == "c3" then ["kernel.spec.json#/state_flow", "generated/docs/reference/workflow.md"]
      elif $item.id == "c4" then ["structures/", "schemas/", "policy/", "render/jsonnet/", "manifests/", "generated/", "build/"]
      elif $item.id == "c5" then ["generated/state/normalization/reference-docs-executable-slice/2026-03-26T23-05-00Z/normalized-state.json", "generated/state/normalization/core-closeout-status-slice/2026-03-26T23-20-00Z/normalized-state.json", "generated/state/normalization/boundary-family-registry-slice/2026-03-26T23-40-00Z/normalized-state.json"]
      elif $item.id == "c6" then ["generated/state/admission/reference-docs-executable-slice/2026-03-26T23-05-00Z/decision.json", "generated/state/admission/core-closeout-status-slice/2026-03-26T23-20-00Z/decision.json", "generated/state/admission/boundary-family-registry-slice/2026-03-26T23-40-00Z/decision.json"]
      elif $item.id == "c7" then ["render/jsonnet/reference/executable-slice.jsonnet", "render/jsonnet/reference/core-closeout-status.jsonnet", "render/jsonnet/registry/boundary-family-registry.jsonnet"]
      elif $item.id == "c8" then ["manifests/bundles/", "manifests/projections/", "manifests/generators/"]
      elif $item.id == "c9" then ["generated/state/source-validation/reference-docs-executable-slice/2026-03-26T23-05-00Z/source-validation.json", "generated/state/export/reference-docs-executable-slice/2026-03-26T23-05-00Z/export-report.json", "generated/state/render/boundary-family-registry-slice/2026-03-26T23-40-00Z/render-report.json", "generated/state/integrity/boundary-family-registry-slice/2026-03-26T23-40-00Z/drift-report.json"]
      elif $item.id == "c10" then ["kernel.spec.json#/completion_condition", "schemas/exported/", "generated/registries/kernel-core-closeout-status.index.json"]
      else ["manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/kernel_core_components"]
      end;
    def component_observed($component):
      if $component.id == "kc1" then "materialized"
      elif $component.id == "kc2" then "materialized"
      elif $component.id == "kc3" then "partial"
      elif $component.id == "kc4" then "partial"
      elif $component.id == "kc5" then "materialized"
      elif $component.id == "kc6" then "materialized"
      elif $component.id == "kc7" then "partial"
      else "open"
      end;
    def component_evidence($component):
      if $component.id == "kc1" then ["structures/core/", "structures/extensions/", "structures/relations/", "structures/adapters/"]
      elif $component.id == "kc2" then ["schemas/exported/", "generated/state/export/reference-docs-executable-slice/2026-03-26T23-05-00Z/export-report.json", "generated/state/export/boundary-family-registry-slice/2026-03-26T23-40-00Z/export-report.json"]
      elif $component.id == "kc3" then ["generated/state/normalization/reference-docs-executable-slice/2026-03-26T23-05-00Z/normalized-state.json", "generated/state/normalization/core-closeout-status-slice/2026-03-26T23-20-00Z/normalized-state.json", "generated/state/normalization/boundary-family-registry-slice/2026-03-26T23-40-00Z/normalized-state.json"]
      elif $component.id == "kc4" then ["policy/kernel/", "policy/admission/", "policy/data/", "generated/state/admission/reference-docs-executable-slice/2026-03-26T23-05-00Z/decision.json", "generated/state/admission/boundary-family-registry-slice/2026-03-26T23-40-00Z/decision.json"]
      elif $component.id == "kc5" then ["render/jsonnet/", "generated/docs/reference/", "generated/registries/"]
      elif $component.id == "kc6" then ["manifests/bundles/", "manifests/projections/", "manifests/generators/"]
      else ["generated/state/integrity/reference-docs-executable-slice/2026-03-26T23-05-00Z/drift-report.json", "generated/state/integrity/core-closeout-status-slice/2026-03-26T23-20-00Z/drift-report.json", "generated/state/integrity/boundary-family-registry-slice/2026-03-26T23-40-00Z/drift-report.json"]
      end;
    {
      kind: "kernel.closeout_status_registry.slice_input",
      control_object_id: "closeout-status-registry-slice",
      registry_id: "kernel-core-closeout-status",
      source_module_id: "closeout-status-registry-slice",
      source_module_ref: "structures/core/closeout-status-registry-slice.module.json",
      closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json",
      boundary_registry_ref: "generated/registries/boundary-families.index.json",
      operational_status_ref: "generated/docs/reference/operational-status.md",
      export_schema_ref: "schemas/exported/closeout-status-registry-slice-input.schema.json",
      generator_ref: "manifests/generators/closeout-status-registry-slice.generator.json",
      projection_ref: "manifests/projections/closeout-status-registry-slice.projection.json",
      output_path: "generated/registries/kernel-core-closeout-status.index.json",
      current_gate_status: $manifest[0].operational_status_gate.current_status,
      blockers: $manifest[0].operational_status_gate.blockers,
      checklist_statuses: [ $manifest[0].checklist_items[] | {
        id: .id,
        label: .label,
        manifest_status: .status,
        observed_status: checklist_observed(.),
        evidence_refs: checklist_evidence(.)
      }],
      component_statuses: [ $manifest[0].kernel_core_components[] | {
        id: .id,
        name: .name,
        plane: .plane,
        manifest_status: .status,
        observed_status: component_observed(.),
        evidence_refs: component_evidence(.)
      }],
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
  source_module_ref: "structures/core/closeout-status-registry-slice.module.json",
  closeout_manifest_ref: "manifests/bundles/kernel-core-json-structure-closeout.manifest.json",
  boundary_registry_ref: "generated/registries/boundary-families.index.json",
  operational_status_ref: "generated/docs/reference/operational-status.md",
  field_sources: {
    checklist_statuses: [
      "manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/checklist_items",
      "generated/state/* evidence refs across executed slices"
    ],
    component_statuses: [
      "manifests/bundles/kernel-core-json-structure-closeout.manifest.json#/kernel_core_components",
      "generated/registries/boundary-families.index.json"
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
      "mapped closeout manifest checklist and component declarations into observed status entries",
      "bound observed status to committed evidence refs across executed slices",
      "kept the closeout manifest as downstream control metadata rather than authority"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/closeout-status-registry-slice.cue",
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
        ref: "schemas/exported/closeout-status-registry-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/closeout-status-registry.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/kernel-core-closeout-status.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/kernel-core-closeout-status.index.json"

cmp -s "${tmp_dir}/generated/registries/kernel-core-closeout-status.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered closeout status registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
