#!/usr/bin/env bash

set -euo pipefail

control_id="json-family-bridge-runtime-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/extensions/json-family-bridge-runtime-slice.module.json"
kernel_policy="policy/kernel/json-family-bridge-runtime.index.json"
exported_schema="schemas/exported/json-family-bridge-runtime-slice-input.schema.json"
policy_bundle="policy/admission/json-family-bridge-runtime-slice.cue"
render_template="render/jsonnet/registry/json-family-bridge-runtime.jsonnet"
rendered_registry="generated/registries/json-family-bridge-runtime.index.json"

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

module_schema="$(mktemp)"
policy_schema="$(mktemp)"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["kind", "id", "fragments", "relations", "notes"],
  "properties": {
    "kind": {"const": "kernel-structure-module"},
    "id": {"const": "json-family-bridge-runtime-slice"},
    "fragments": {
      "type": "array",
      "minItems": 4,
      "items": {
        "type": "object",
        "required": ["name", "class", "source_refs", "description"],
        "properties": {
          "name": {"type": "string"},
          "class": {"const": "extension"},
          "source_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "description": {"type": "string"}
        },
        "additionalProperties": false
      }
    },
    "relations": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["from", "to", "relation"],
        "properties": {
          "from": {"type": "string"},
          "to": {"type": "string"},
          "relation": {"type": "string"}
        },
        "additionalProperties": false
      }
    },
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${module_schema}"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["policy_id", "status", "authority_format", "summary", "bridge_classes", "runtime_actor_classes", "promotion_defaults"],
  "properties": {
    "policy_id": {"const": "json-family-bridge-runtime"},
    "status": {"const": "structural_only"},
    "authority_format": {"const": "canonical_structural_model"},
    "summary": {"type": "string"},
    "authoritative_surfaces": {"type": "array", "items": {"type": "string"}, "minItems": 1},
    "bridge_classes": {
      "type": "array",
      "minItems": 2,
      "items": {
        "type": "object",
        "required": ["class_id", "authority_status", "consumes", "produces", "promotion_default", "lineage_sink_required"],
        "properties": {
          "class_id": {"type": "string"},
          "native_examples": {"type": "array", "items": {"type": "string"}},
          "authority_status": {"const": "derived"},
          "consumes": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "produces": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "promotion_default": {"const": "blocked"},
          "lineage_sink_required": {"const": true}
        },
        "additionalProperties": false
      }
    },
    "runtime_actor_classes": {
      "type": "array",
      "minItems": 5,
      "items": {
        "type": "object",
        "required": ["class_id", "authority_status", "consumes", "emitter_side_effect_class", "lineage_sink_required"],
        "properties": {
          "class_id": {"type": "string"},
          "authority_status": {"const": "derived"},
          "consumes": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "produces": {"type": "array", "items": {"type": "string"}},
          "emitter_side_effect_class": {"const": "declared_required"},
          "lineage_sink_required": {"const": true}
        },
        "additionalProperties": false
      }
    },
    "promotion_defaults": {
      "type": "object",
      "required": ["authority_promotion_of_bridge_output", "authority_promotion_of_runtime_output", "explicit_promotion_policy_required"],
      "properties": {
        "authority_promotion_of_bridge_output": {"const": "forbidden_by_default"},
        "authority_promotion_of_runtime_output": {"const": "forbidden_by_default"},
        "explicit_promotion_policy_required": {"const": true}
      },
      "additionalProperties": false
    },
    "excluded_content": {"type": "array", "items": {"type": "string"}},
    "derived_from": {"type": "array", "items": {"type": "string"}},
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${policy_schema}"

g1_module_json="$(mktemp)"
g1_policy_json="$(mktemp)"
if check-jsonschema --schemafile "${module_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_module_json}" \
  && check-jsonschema --schemafile "${policy_schema}" --output-format json "${repo_root}/${kernel_policy}" >"${g1_policy_json}"; then
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
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile module_tool_output "${g1_module_json}" \
  --slurpfile policy_tool_output "${g1_policy_json}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema",
    tool_output: {
      source_module: $module_tool_output[0],
      kernel_policy: $policy_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${module_schema}" "${policy_schema}" "${g1_module_json}" "${g1_policy_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "json-family-bridge-runtime-slice-input.schema.json",
  "title": "JSON-family bridge/runtime slice input",
  "description": "Derived boundary contract for the JSON-family bridge/runtime registry slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "source_module_id",
    "source_module_ref",
    "kernel_policy_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "entries",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.bridge_runtime_registry.slice_input"},
    "control_object_id": {"const": "json-family-bridge-runtime-slice"},
    "source_module_id": {"const": "json-family-bridge-runtime-slice"},
    "source_module_ref": {"const": "structures/extensions/json-family-bridge-runtime-slice.module.json"},
    "kernel_policy_ref": {"const": "policy/kernel/json-family-bridge-runtime.index.json"},
    "export_schema_ref": {"const": "schemas/exported/json-family-bridge-runtime-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/json-family-bridge-runtime-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/json-family-bridge-runtime-slice.projection.json"},
    "output_path": {"const": "generated/registries/json-family-bridge-runtime.index.json"},
    "entries": {
      "type": "array",
      "minItems": 8,
      "items": {
        "type": "object",
        "required": ["entry_id", "entry_class", "summary", "authority_status", "source_refs", "promotion_default", "lineage_sink_required"],
        "properties": {
          "entry_id": {"type": "string"},
          "entry_class": {"type": "string", "enum": ["authoring_surface", "bridge_class", "runtime_actor_class", "guardrail"]},
          "summary": {"type": "string"},
          "authority_status": {"type": "string", "enum": ["authoritative", "derived"]},
          "source_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "consumes": {"type": "array", "items": {"type": "string"}},
          "produces": {"type": "array", "items": {"type": "string"}},
          "promotion_default": {"type": "string", "enum": ["blocked", "not_applicable"]},
          "lineage_sink_required": {"type": "boolean"},
          "emitter_side_effect_class": {"type": "string"}
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
  --arg schema_ref "${exported_schema}" \
  --arg exported_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile tool_output "${g2_json}" \
  --argjson reason_codes "${g2_reasons}" \
  '{
    gate: "G2",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
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
  --slurpfile module "${repo_root}/${source_module}" \
  --slurpfile policy "${repo_root}/${kernel_policy}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.bridge_runtime_registry.slice_input",
    control_object_id: "json-family-bridge-runtime-slice",
    source_module_id: "json-family-bridge-runtime-slice",
    source_module_ref: "structures/extensions/json-family-bridge-runtime-slice.module.json",
    kernel_policy_ref: "policy/kernel/json-family-bridge-runtime.index.json",
    export_schema_ref: "schemas/exported/json-family-bridge-runtime-slice-input.schema.json",
    generator_ref: "manifests/generators/json-family-bridge-runtime-slice.generator.json",
    projection_ref: "manifests/projections/json-family-bridge-runtime-slice.projection.json",
    output_path: "generated/registries/json-family-bridge-runtime.index.json",
    entries: (
      [
        {
          entry_id: "json-structure-authoring-surface",
          entry_class: "authoring_surface",
          summary: $module[0].fragments[0].description,
          authority_status: "authoritative",
          source_refs: $module[0].fragments[0].source_refs,
          produces: ["normalized structural drafts"],
          promotion_default: "not_applicable",
          lineage_sink_required: false
        }
      ]
      + ($policy[0].bridge_classes | map({
          entry_id: .class_id,
          entry_class: "bridge_class",
          summary: ((.native_examples // []) | if length > 0 then "Derived bridge class for " + (join(", ")) else "Derived bridge class" end),
          authority_status: .authority_status,
          source_refs: ["policy/kernel/json-family-bridge-runtime.index.json#/bridge_classes"],
          consumes: .consumes,
          produces: .produces,
          promotion_default: (if .promotion_default == "blocked" then "blocked" else "not_applicable" end),
          lineage_sink_required: .lineage_sink_required
      }))
      + ($policy[0].runtime_actor_classes | map({
          entry_id: .class_id,
          entry_class: "runtime_actor_class",
          summary: "Derived runtime actor class",
          authority_status: .authority_status,
          source_refs: ["policy/kernel/json-family-bridge-runtime.index.json#/runtime_actor_classes"],
          consumes: .consumes,
          produces: (.produces // []),
          promotion_default: "blocked",
          lineage_sink_required: .lineage_sink_required,
          emitter_side_effect_class: .emitter_side_effect_class
      }))
      + [
        {
          entry_id: "promotion-and-lineage-guardrails",
          entry_class: "guardrail",
          summary: $module[0].fragments[3].description,
          authority_status: "derived",
          source_refs: $module[0].fragments[3].source_refs,
          consumes: ["admitted state", "rendered artifacts"],
          produces: ["lineage evidence", "promotion decisions"],
          promotion_default: "blocked",
          lineage_sink_required: true,
          emitter_side_effect_class: "declared_required"
        }
      ]
    ),
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
  source_module_ref: "structures/extensions/json-family-bridge-runtime-slice.module.json",
  field_sources: {
    authoring_surface: ["structures/extensions/json-family-bridge-runtime-slice.module.json#/fragments/0"],
    bridge_classes: ["policy/kernel/json-family-bridge-runtime.index.json#/bridge_classes"],
    runtime_actor_classes: ["policy/kernel/json-family-bridge-runtime.index.json#/runtime_actor_classes"],
    promotion_guardrails: ["structures/extensions/json-family-bridge-runtime-slice.module.json#/fragments/3"],
    output_path: ["manifests/projections/json-family-bridge-runtime-slice.projection.json"]
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
      "bound extension-module fragments and kernel policy declarations into one normalized registry input",
      "preserved bridge and runtime classes as derived declarations",
      "recorded promotion-default and lineage requirements without inventing controller behavior"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/json-family-bridge-runtime-slice.cue",
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
        ref: "schemas/exported/json-family-bridge-runtime-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/json-family-bridge-runtime.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/json-family-bridge-runtime.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/json-family-bridge-runtime.index.json"

cmp -s "${tmp_dir}/generated/registries/json-family-bridge-runtime.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered bridge/runtime registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
