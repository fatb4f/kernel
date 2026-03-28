#!/usr/bin/env bash

set -euo pipefail

control_id="prose-contract-workflow-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/extensions/prose-contract-workflow-slice.module.json"
kernel_policy="policy/kernel/prose-contract-workflow.index.json"
contract_note="policy/contracts/prose-contract-workflow.md"
lineage_index="policy/data/prose-contract-lineage.index.json"
exported_schema="schemas/exported/prose-contract-workflow-slice-input.schema.json"
policy_bundle="policy/admission/prose-contract-workflow-slice.cue"
render_template="render/jsonnet/registry/prose-contract-workflow.jsonnet"
rendered_registry="generated/registries/prose-contract-workflow.index.json"

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
lineage_schema="$(mktemp)"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["kind", "id", "fragments", "relations", "notes"],
  "properties": {
    "kind": {"const": "kernel-structure-module"},
    "id": {"const": "prose-contract-workflow-slice"},
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
  "required": ["policy_id", "status", "summary", "authority_sentence", "term_bindings", "workflow_rules", "preferred_export_bundle"],
  "properties": {
    "policy_id": {"const": "prose-contract-workflow"},
    "status": {"const": "structural_only"},
    "summary": {"type": "string"},
    "authority_sentence": {"type": "string"},
    "term_bindings": {
      "type": "object",
      "required": ["reviewed_structural_draft", "normalized_state", "admitted_state", "constraint_manifest", "derived_export", "auxiliary_workflow_graph"],
      "additionalProperties": {"type": "string"}
    },
    "workflow_rules": {"type": "array", "items": {"type": "string"}, "minItems": 1},
    "preferred_export_bundle": {
      "type": "object",
      "required": ["members", "merged_convenience_export"],
      "properties": {
        "members": {"type": "array", "items": {"type": "string"}, "minItems": 3},
        "merged_convenience_export": {"const": "optional_derived_only"}
      },
      "additionalProperties": false
    },
    "excluded_content": {"type": "array", "items": {"type": "string"}},
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${policy_schema}"

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["lineage_id", "status", "edges", "notes"],
  "properties": {
    "lineage_id": {"const": "prose-contract-workflow"},
    "status": {"const": "structural_only"},
    "edges": {
      "type": "array",
      "minItems": 8,
      "items": {
        "type": "object",
        "required": ["artifact", "relation", "target"],
        "properties": {
          "artifact": {"type": "string"},
          "relation": {"type": "string", "enum": ["generated_from", "validated_against"]},
          "target": {"type": "string"}
        },
        "additionalProperties": false
      }
    },
    "notes": {"type": "string"}
  },
  "additionalProperties": false
}' >"${lineage_schema}"

g1_module_json="$(mktemp)"
g1_policy_json="$(mktemp)"
g1_lineage_json="$(mktemp)"
if check-jsonschema --schemafile "${module_schema}" --output-format json "${repo_root}/${source_module}" >"${g1_module_json}" \
  && check-jsonschema --schemafile "${policy_schema}" --output-format json "${repo_root}/${kernel_policy}" >"${g1_policy_json}" \
  && check-jsonschema --schemafile "${lineage_schema}" --output-format json "${repo_root}/${lineage_index}" >"${g1_lineage_json}" \
  && rg -n "^## reviewed-structural-draft|^## graph-boundary|^## derived-artifact-family|^## consumer-export-policy" "${repo_root}/${contract_note}" >/dev/null; then
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
  --slurpfile lineage_tool_output "${g1_lineage_json}" \
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
      lineage_index: $lineage_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${module_schema}" "${policy_schema}" "${lineage_schema}" "${g1_module_json}" "${g1_policy_json}" "${g1_lineage_json}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "prose-contract-workflow-slice-input.schema.json",
  "title": "Prose contract workflow slice input",
  "description": "Derived boundary contract for the revised prose contract workflow slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "source_module_id",
    "source_module_ref",
    "kernel_policy_ref",
    "contract_note_ref",
    "lineage_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "entries",
    "preferred_export_bundle",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.prose_contract_workflow.slice_input"},
    "control_object_id": {"const": "prose-contract-workflow-slice"},
    "source_module_id": {"const": "prose-contract-workflow-slice"},
    "source_module_ref": {"const": "structures/extensions/prose-contract-workflow-slice.module.json"},
    "kernel_policy_ref": {"const": "policy/kernel/prose-contract-workflow.index.json"},
    "contract_note_ref": {"const": "policy/contracts/prose-contract-workflow.md"},
    "lineage_ref": {"const": "policy/data/prose-contract-lineage.index.json"},
    "export_schema_ref": {"const": "schemas/exported/prose-contract-workflow-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/prose-contract-workflow-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/prose-contract-workflow-slice.projection.json"},
    "output_path": {"const": "generated/registries/prose-contract-workflow.index.json"},
    "entries": {
      "type": "array",
      "minItems": 10,
      "items": {
        "type": "object",
        "required": ["entry_id", "entry_class", "summary", "source_refs", "authority_role"],
        "properties": {
          "entry_id": {"type": "string"},
          "entry_class": {"type": "string", "enum": ["term_binding", "workflow_rule", "export_family", "lineage_expectation"]},
          "summary": {"type": "string"},
          "source_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "authority_role": {"type": "string", "enum": ["pre_contract", "contract_surface", "derived", "non_authoritative"]}
        },
        "additionalProperties": false
      }
    },
    "preferred_export_bundle": {
      "type": "object",
      "required": ["members", "merged_convenience_export"],
      "properties": {
        "members": {"type": "array", "items": {"type": "string"}, "minItems": 3},
        "merged_convenience_export": {"const": "optional_derived_only"}
      },
      "additionalProperties": false
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
  --slurpfile lineage "${repo_root}/${lineage_index}" \
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.prose_contract_workflow.slice_input",
    control_object_id: "prose-contract-workflow-slice",
    source_module_id: "prose-contract-workflow-slice",
    source_module_ref: "structures/extensions/prose-contract-workflow-slice.module.json",
    kernel_policy_ref: "policy/kernel/prose-contract-workflow.index.json",
    contract_note_ref: "policy/contracts/prose-contract-workflow.md",
    lineage_ref: "policy/data/prose-contract-lineage.index.json",
    export_schema_ref: "schemas/exported/prose-contract-workflow-slice-input.schema.json",
    generator_ref: "manifests/generators/prose-contract-workflow-slice.generator.json",
    projection_ref: "manifests/projections/prose-contract-workflow-slice.projection.json",
    output_path: "generated/registries/prose-contract-workflow.index.json",
    entries: (
      [
        {
          entry_id: "reviewed_structural_draft",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.reviewed_structural_draft,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/reviewed_structural_draft", "policy/contracts/prose-contract-workflow.md#/reviewed-structural-draft"],
          authority_role: "pre_contract"
        },
        {
          entry_id: "normalized_state",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.normalized_state,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/normalized_state"],
          authority_role: "derived"
        },
        {
          entry_id: "admitted_state",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.admitted_state,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/admitted_state"],
          authority_role: "derived"
        },
        {
          entry_id: "constraint_manifest",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.constraint_manifest,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/constraint_manifest"],
          authority_role: "derived"
        },
        {
          entry_id: "derived_export",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.derived_export,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/derived_export"],
          authority_role: "derived"
        },
        {
          entry_id: "auxiliary_workflow_graph",
          entry_class: "term_binding",
          summary: $policy[0].term_bindings.auxiliary_workflow_graph,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings/auxiliary_workflow_graph", "policy/contracts/prose-contract-workflow.md#/graph-boundary"],
          authority_role: "non_authoritative"
        }
      ]
      + ($policy[0].workflow_rules | to_entries | map({
          entry_id: "workflow_rule_" + (.key|tostring),
          entry_class: "workflow_rule",
          summary: .value,
          source_refs: ["policy/kernel/prose-contract-workflow.index.json#/workflow_rules"],
          authority_role: (if (.value | test("JSON Structure is|Generation proceeds from the reviewed structural draft")) then "contract_surface" else "derived" end)
      }))
      + [
        {
          entry_id: "preferred_export_bundle",
          entry_class: "export_family",
          summary: "Preferred derived export bundle for structural schema, constraints, and preservation reporting.",
          source_refs: ["policy/contracts/prose-contract-workflow.md#/consumer-export-policy", "policy/kernel/prose-contract-workflow.index.json#/preferred_export_bundle"],
          authority_role: "derived"
        }
      ]
      + ($lineage[0].edges | map({
          entry_id: (.artifact + "__" + .relation),
          entry_class: "lineage_expectation",
          summary: (.artifact + " " + .relation + " " + .target),
          source_refs: ["policy/data/prose-contract-lineage.index.json#/edges"],
          authority_role: "derived"
      }))
    ),
    preferred_export_bundle: $policy[0].preferred_export_bundle,
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
  source_module_ref: "structures/extensions/prose-contract-workflow-slice.module.json",
  field_sources: {
    term_bindings: ["policy/kernel/prose-contract-workflow.index.json#/term_bindings"],
    workflow_rules: ["policy/kernel/prose-contract-workflow.index.json#/workflow_rules"],
    contract_note: ["policy/contracts/prose-contract-workflow.md"],
    lineage_edges: ["policy/data/prose-contract-lineage.index.json#/edges"],
    output_path: ["manifests/projections/prose-contract-workflow-slice.projection.json"]
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
      "bound source, policy, contract, and lineage workflow surfaces into one normalized registry input",
      "preserved graph-like aids as optional and non-authoritative",
      "bound the preferred derived export family and minimum lineage expectations"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/prose-contract-workflow-slice.cue",
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
        ref: "schemas/exported/prose-contract-workflow-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/prose-contract-workflow.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/prose-contract-workflow.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/prose-contract-workflow.index.json"

cmp -s "${tmp_dir}/generated/registries/prose-contract-workflow.index.json" "${repo_root}/${rendered_registry}"

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
      "rendered workflow registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf '%s\n' "${run_id}"
