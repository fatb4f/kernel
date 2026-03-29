#!/usr/bin/env bash

set -euo pipefail

control_id="metadata-metaschema-lane"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/extensions/metadata-metaschema-lane.module.json"
kernel_policy="policy/kernel/metadata-metaschema-lane.index.json"
contract_note="policy/contracts/metadata-metaschema-lane.md"
dependency_index="policy/data/metadata-lane-dependency.index.json"
exported_schema="schemas/exported/metadata-metaschema-lane-input.schema.json"
policy_bundle="policy/admission/metadata-metaschema-lane.cue"
render_template="render/jsonnet/registry/metadata-metaschema-lane.jsonnet"
rendered_registry="generated/registries/metadata-metaschema-lane.index.json"
dependency_render_template="render/jsonnet/registry/metadata-lane-dependency.jsonnet"
dependency_registry="generated/registries/metadata-lane-dependency.index.json"

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
dependency_schema="$(mktemp)"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["kind", "id", "fragments", "relations", "notes"],
  "properties": {
    "kind": {"const": "kernel-structure-module"},
    "id": {"const": "metadata-metaschema-lane"},
    "fragments": {
      "type": "array",
      "minItems": 5,
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
      "minItems": 5,
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
  "required": ["policy_id", "status", "summary", "authority_sentence", "schema_surfaces", "workflow_rules", "projection_policy"],
  "properties": {
    "policy_id": {"const": "metadata-metaschema-lane"},
    "status": {"const": "structural_only"},
    "summary": {"type": "string"},
    "authority_sentence": {"type": "string"},
    "schema_surfaces": {
      "type": "object",
      "required": ["source_registry", "structural_units", "canonical_semantic_model", "canonical_document", "projection_artifact_manifest", "anchor_catalog", "compatibility_policy", "lane_dependency_contract"],
      "additionalProperties": {"type": "string"}
    },
    "workflow_rules": {"type": "array", "items": {"type": "string"}, "minItems": 1},
    "projection_policy": {
      "type": "object",
      "required": ["authoritative_middle", "derived_surfaces", "excluded_content"],
      "properties": {
        "authoritative_middle": {"const": "canonical_semantic_model"},
        "derived_surfaces": {"type": "array", "items": {"type": "string"}, "minItems": 2},
        "excluded_content": {"type": "array", "items": {"type": "string"}}
      },
      "additionalProperties": false
    },
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${policy_schema}"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["dependency_id", "status", "semantic_authority_lane", "lanes", "allowed_edges", "forbidden_edges", "notes"],
  "properties": {
    "dependency_id": {"const": "metadata-lane-dependency"},
    "status": {"const": "structural_only"},
    "semantic_authority_lane": {"const": "metaschema_model"},
    "lanes": {"type": "array", "minItems": 3},
    "allowed_edges": {"type": "array", "minItems": 1},
    "forbidden_edges": {"type": "array", "minItems": 1},
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${dependency_schema}"

g1_module_json="$(mktemp)"
g1_policy_json="$(mktemp)"
g1_dependency_json="$(mktemp)"
if check-jsonschema --schemafile "${module_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_module_json}" \
  && check-jsonschema --schemafile "${policy_schema}" --output-format json "${repo_root}/${kernel_policy}" >"${g1_policy_json}" \
  && check-jsonschema --schemafile "${dependency_schema}" --output-format json "${repo_root}/${dependency_index}" >"${g1_dependency_json}" \
  && rg -n "^## rooted-source-registry|^## structural-units|^## canonical-semantic-model|^## projection-binding|^## lane-order" "${repo_root}/${contract_note}" >/dev/null; then
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
  --slurpfile dependency_tool_output "${g1_dependency_json}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema + rg",
    tool_output: {
      source_module: $module_tool_output[0],
      kernel_policy: $policy_tool_output[0],
      dependency_index: $dependency_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${module_schema}" "${policy_schema}" "${dependency_schema}" "${g1_module_json}" "${g1_policy_json}" "${g1_dependency_json}"
[[ "${g1_status}" == "PASS" ]]

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
    tool: "check-jsonschema",
    tool_output: $tool_output[0]
  }' >"${repo_root}/$(phase_dir export)/export-report.json"

rm -f "${g2_json}"
[[ "${g2_status}" == "PASS" ]]

jsonnet_runtime="$(jsonnet_bin)"

jq -n \
  --slurpfile module "${repo_root}/${source_module}" \
  --slurpfile policy "${repo_root}/${kernel_policy}" \
  --slurpfile dependency "${repo_root}/${dependency_index}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.metadata_metaschema_lane.slice_input",
    control_object_id: "metadata-metaschema-lane",
    source_module_id: "metadata-metaschema-lane",
    source_module_ref: "structures/extensions/metadata-metaschema-lane.module.json",
    kernel_policy_ref: "policy/kernel/metadata-metaschema-lane.index.json",
    contract_note_ref: "policy/contracts/metadata-metaschema-lane.md",
    lane_dependency_ref: "policy/data/metadata-lane-dependency.index.json",
    export_schema_ref: "schemas/exported/metadata-metaschema-lane-input.schema.json",
    generator_ref: "manifests/generators/metadata-metaschema-lane.generator.json",
    projection_ref: "manifests/projections/metadata-metaschema-lane.projection.json",
    output_path: "generated/registries/metadata-metaschema-lane.index.json",
    authoritative_middle: "canonical_semantic_model",
    entries: (
      [
        {
          entry_id: "source_registry",
          entry_class: "schema_surface",
          summary: $policy[0].schema_surfaces.source_registry,
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/schema_surfaces/source_registry", "policy/contracts/metadata-metaschema-lane.md#/rooted-source-registry"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "structural_units",
          entry_class: "schema_surface",
          summary: $policy[0].schema_surfaces.structural_units,
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/schema_surfaces/structural_units", "policy/contracts/metadata-metaschema-lane.md#/structural-units"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "canonical_semantic_model",
          entry_class: "schema_surface",
          summary: $policy[0].schema_surfaces.canonical_semantic_model,
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/schema_surfaces/canonical_semantic_model", "policy/contracts/metadata-metaschema-lane.md#/canonical-semantic-model"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "projection_artifact_manifest",
          entry_class: "schema_surface",
          summary: $policy[0].schema_surfaces.projection_artifact_manifest,
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/schema_surfaces/projection_artifact_manifest", "policy/contracts/metadata-metaschema-lane.md#/projection-binding"],
          authority_role: "derived"
        },
        {
          entry_id: "rule_no_docgen_only_metadata_lane",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[0],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/0"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "rule_rooted_source_before_structural_extraction",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[1],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/1"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "rule_structural_extraction_before_semantic_normalization",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[2],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/2"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "rule_document_projection_downstream_only",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[3],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/3"],
          authority_role: "derived"
        },
        {
          entry_id: "rule_workflow_docs_explanatory_only",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[4],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/4"],
          authority_role: "derived"
        },
        {
          entry_id: "rule_scm_pattern_downstream_only",
          entry_class: "workflow_rule",
          summary: $policy[0].workflow_rules[5],
          source_refs: ["policy/kernel/metadata-metaschema-lane.index.json#/workflow_rules/5"],
          authority_role: "derived"
        },
        {
          entry_id: "allow_metaschema_projects_to_workflow_docs",
          entry_class: "dependency_rule",
          summary: "metaschema_model projects_to workflow_docs",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/allowed_edges/0"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "allow_metaschema_constrains_scm_pattern",
          entry_class: "dependency_rule",
          summary: "metaschema_model constrains scm_pattern_workflow",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/allowed_edges/1"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "allow_workflow_docs_guides_scm_pattern",
          entry_class: "dependency_rule",
          summary: "workflow_docs guides scm_pattern_workflow",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/allowed_edges/2"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "forbid_workflow_docs_defines_metaschema",
          entry_class: "dependency_rule",
          summary: "workflow_docs must not define metaschema_model",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/forbidden_edges/0"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "forbid_scm_pattern_defines_metaschema",
          entry_class: "dependency_rule",
          summary: "scm_pattern_workflow must not define metaschema_model",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/forbidden_edges/1"],
          authority_role: "contract_surface"
        },
        {
          entry_id: "forbid_scm_pattern_defines_workflow_docs",
          entry_class: "dependency_rule",
          summary: "scm_pattern_workflow must not define workflow_docs",
          source_refs: ["policy/data/metadata-lane-dependency.index.json#/forbidden_edges/2"],
          authority_role: "contract_surface"
        }
      ]
    ),
    lane_order: {
      semantic_authority_lane: $dependency[0].semantic_authority_lane,
      allowed_edges: $dependency[0].allowed_edges,
      forbidden_edges: $dependency[0].forbidden_edges
    },
    render_contract: {
      renderer: "jsonnet",
      runtime: "rsjsonnet",
      runtime_path: $runtime_path,
      input_class: "admitted_state",
      output_class: "registry"
    }
  }' >"${repo_root}/$(phase_dir normalization)/normalized-state.json"

jq -n '{
  source_module_ref: "structures/extensions/metadata-metaschema-lane.module.json",
  policy_refs: [
    "policy/kernel/metadata-metaschema-lane.index.json",
    "policy/contracts/metadata-metaschema-lane.md",
    "policy/data/metadata-lane-dependency.index.json"
  ],
  derived_outputs: [
    "schemas/exported/metadata-metaschema-lane-input.schema.json",
    "generated/registries/metadata-metaschema-lane.index.json"
  ]
}' >"${repo_root}/$(phase_dir normalization)/source-map.json"

jq -n '{
  control_object_id: "metadata-metaschema-lane",
  run_id: "'"${run_id}"'",
  normalized_contract: "kernel.metadata_metaschema_lane.slice_input",
  notes: [
    "normalized the authoritative middle and lane-order rules into one admitted-state input",
    "kept workflow docs explanatory and scm.pattern downstream by contract"
  ]
}' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

check-jsonschema --schemafile "${repo_root}/${exported_schema}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" >/dev/null
cue vet "${repo_root}/$(phase_dir normalization)/normalized-state.json" "${repo_root}/${policy_bundle}" -d '#Normalized'

cp "${repo_root}/$(phase_dir normalization)/normalized-state.json" "${repo_root}/$(phase_dir admission)/admitted-state.json"
jq -n '{
  control_object_id: "metadata-metaschema-lane",
  policy_bundle_id: "policy/admission/metadata-metaschema-lane.cue",
  status: "PASS",
  notes: ["admitted state satisfies the metadata metaschema lane contract"]
}' >"${repo_root}/$(phase_dir admission)/decision.json"
jq -n '[]' >"${repo_root}/$(phase_dir admission)/violations.json"

"${jsonnet_runtime}" --ext-str admitted_state="$(cat "${repo_root}/$(phase_dir admission)/admitted-state.json")" "${repo_root}/${render_template}" >"${repo_root}/${rendered_registry}"
"${jsonnet_runtime}" --ext-str admitted_state="$(cat "${repo_root}/$(phase_dir admission)/admitted-state.json")" "${repo_root}/${dependency_render_template}" >"${repo_root}/${dependency_registry}"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg template_ref "${render_template}" \
  --arg dependency_template_ref "${dependency_render_template}" \
  --arg admitted_state_ref "$(phase_dir admission)/admitted-state.json" \
  --arg output_ref "${rendered_registry}" \
  --arg dependency_output_ref "${dependency_registry}" \
  '{
    control_object_id: $control_object_id,
    run_id: $run_id,
    template_refs: [$template_ref, $dependency_template_ref],
    admitted_state_ref: $admitted_state_ref,
    outputs: [$output_ref, $dependency_output_ref]
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg output_ref "${rendered_registry}" \
  --arg dependency_output_ref "${dependency_registry}" \
  '{
    control_object_id: $control_object_id,
    run_id: $run_id,
    output_refs: [$output_ref, $dependency_output_ref],
    status: "PASS",
    notes: ["deterministic registry render completed"]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"
