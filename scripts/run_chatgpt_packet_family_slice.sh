#!/usr/bin/env bash

set -euo pipefail

control_id="chatgpt-packet-family-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/chatgpt-packet-family-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
exported_schema="schemas/exported/chatgpt-packet-family-slice-input.schema.json"
policy_bundle="policy/admission/chatgpt-packet-family-slice.cue"
render_template="render/jsonnet/registry/chatgpt-packet-family.jsonnet"
rendered_registry="generated/registries/chatgpt-packet-family.index.json"

schema_files=(
  "generated/schemas/chatgpt-pipeline/packet/authority.manifest.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/packet.definition.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/scm.pattern.binding.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/packet.review.request.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/packet.review.decision.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/root.trust.evidence.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/regen.record.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/artifact.manifest.schema.json"
  "generated/schemas/chatgpt-pipeline/packet/packet.approval.schema.json"
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

g1_source_json="$(mktemp)"
if check-jsonschema \
  --schemafile "${repo_root}/${source_schema}" \
  --output-format json \
  "${repo_root}/${source_module}" >"${g1_source_json}"; then
  g1_status="PASS"
  g1_reasons='[]'
else
  g1_status="FAIL"
  g1_reasons='["SRC_SCHEMA_VALIDATION_FAILED"]'
fi

schema_reports="$(mktemp)"
printf '[]' >"${schema_reports}"
for schema_ref in "${schema_files[@]}"; do
  report_file="$(mktemp)"
  if check-jsonschema --check-metaschema --output-format json "${repo_root}/${schema_ref}" >"${report_file}"; then
    jq --arg ref "${schema_ref}" --slurpfile output "${report_file}" '. + [{schema_ref:$ref, status:"PASS", tool_output:$output[0]}]' "${schema_reports}" >"${schema_reports}.tmp"
  else
    g1_status="FAIL"
    g1_reasons='["SRC_SCHEMA_VALIDATION_FAILED"]'
    jq --arg ref "${schema_ref}" --slurpfile output "${report_file}" '. + [{schema_ref:$ref, status:"FAIL", tool_output:$output[0]}]' "${schema_reports}" >"${schema_reports}.tmp"
  fi
  mv "${schema_reports}.tmp" "${schema_reports}"
  rm -f "${report_file}"
done

jq -n \
  --arg control_object_id "${control_id}" \
  --arg run_id "${run_id}" \
  --arg status "${g1_status}" \
  --arg source_schema_ref "${source_schema}" \
  --arg source_ref "${source_module}" \
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile source_tool_output "${g1_source_json}" \
  --slurpfile schema_tool_output "${schema_reports}" \
  --argjson reason_codes "${g1_reasons}" \
  '{
    gate: "G1",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    source_schema_ref: $source_schema_ref,
    source_ref: $source_ref,
    validated_at: $validated_at,
    reason_codes: $reason_codes,
    tool: "check-jsonschema",
    tool_output: {
      source_module: $source_tool_output[0],
      packet_schemas: $schema_tool_output[0]
    }
  }' >"${repo_root}/$(phase_dir source-validation)/source-validation.json"

rm -f "${g1_source_json}" "${schema_reports}"
[[ "${g1_status}" == "PASS" ]]

jq -n '{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "chatgpt-packet-family-slice-input.schema.json",
  "title": "ChatGPT packet family slice input",
  "description": "Derived boundary contract for the approved ChatGPT packet schema family slice.",
  "type": "object",
  "required": [
    "kind",
    "control_object_id",
    "registry_id",
    "family_root",
    "source_module_id",
    "source_module_ref",
    "export_schema_ref",
    "generator_ref",
    "projection_ref",
    "output_path",
    "approval_state",
    "entries",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.chatgpt_packet_family.slice_input"},
    "control_object_id": {"const": "chatgpt-packet-family-slice"},
    "registry_id": {"const": "kernel-chatgpt-packet-family"},
    "family_root": {"const": "generated/schemas/chatgpt-pipeline/packet"},
    "source_module_id": {"const": "chatgpt-packet-family-slice"},
    "source_module_ref": {"const": "structures/core/chatgpt-packet-family-slice.module.json"},
    "export_schema_ref": {"const": "schemas/exported/chatgpt-packet-family-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/chatgpt-packet-family-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/chatgpt-packet-family-slice.projection.json"},
    "output_path": {"const": "generated/registries/chatgpt-packet-family.index.json"},
    "approval_state": {"const": "APPROVED"},
    "entries": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": [
          "schema_id",
          "schema_role",
          "schema_ref",
          "workflow_binding_refs",
          "source_refs",
          "summary",
          "status"
        ],
        "properties": {
          "schema_id": {"type": "string"},
          "schema_role": {"type": "string"},
          "schema_ref": {"type": "string"},
          "workflow_binding_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "source_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "summary": {"type": "string"},
          "status": {"const": "materialized"}
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
  --arg runtime_path "${jsonnet_runtime}" \
  '{
    kind: "kernel.chatgpt_packet_family.slice_input",
    control_object_id: "chatgpt-packet-family-slice",
    registry_id: "kernel-chatgpt-packet-family",
    family_root: "generated/schemas/chatgpt-pipeline/packet",
    source_module_id: $source[0].id,
    source_module_ref: "structures/core/chatgpt-packet-family-slice.module.json",
    export_schema_ref: "schemas/exported/chatgpt-packet-family-slice-input.schema.json",
    generator_ref: "manifests/generators/chatgpt-packet-family-slice.generator.json",
    projection_ref: "manifests/projections/chatgpt-packet-family-slice.projection.json",
    output_path: "generated/registries/chatgpt-packet-family.index.json",
    approval_state: "APPROVED",
    entries: [
      $source[0].fragments[] | {
        schema_id: .name,
        schema_role: (
          if .name == "authority-manifest-schema" then "authority_manifest"
          elif .name == "packet-definition-schema" then "packet_definition"
          elif .name == "scm-pattern-binding-schema" then "scm_pattern_binding"
          elif .name == "packet-review-request-schema" then "packet_review_request"
          elif .name == "packet-review-decision-schema" then "packet_review_decision"
          elif .name == "root-trust-evidence-schema" then "root_trust_evidence"
          elif .name == "regen-record-schema" then "regen_record"
          elif .name == "artifact-manifest-schema" then "artifact_manifest"
          else "packet_approval"
          end
        ),
        schema_ref: (
          if .name == "authority-manifest-schema" then "generated/schemas/chatgpt-pipeline/packet/authority.manifest.schema.json"
          elif .name == "packet-definition-schema" then "generated/schemas/chatgpt-pipeline/packet/packet.definition.schema.json"
          elif .name == "scm-pattern-binding-schema" then "generated/schemas/chatgpt-pipeline/packet/scm.pattern.binding.schema.json"
          elif .name == "packet-review-request-schema" then "generated/schemas/chatgpt-pipeline/packet/packet.review.request.schema.json"
          elif .name == "packet-review-decision-schema" then "generated/schemas/chatgpt-pipeline/packet/packet.review.decision.schema.json"
          elif .name == "root-trust-evidence-schema" then "generated/schemas/chatgpt-pipeline/packet/root.trust.evidence.schema.json"
          elif .name == "regen-record-schema" then "generated/schemas/chatgpt-pipeline/packet/regen.record.schema.json"
          elif .name == "artifact-manifest-schema" then "generated/schemas/chatgpt-pipeline/packet/artifact.manifest.schema.json"
          else "generated/schemas/chatgpt-pipeline/packet/packet.approval.schema.json"
          end
        ),
        workflow_binding_refs: .source_refs[1:],
        source_refs: .source_refs,
        summary: .description,
        status: "materialized"
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
    source_module_ref: "structures/core/chatgpt-packet-family-slice.module.json",
    family_root: "generated/schemas/chatgpt-pipeline/packet",
    field_sources: {
      entries: [
        {
          family: "approved_chatgpt_packet_family",
          refs: [
            "structures/core/chatgpt-packet-family-slice.module.json",
            "generated/schemas/chatgpt-pipeline/packet/"
          ]
        }
      ],
      output_path: [
        "manifests/projections/chatgpt-packet-family-slice.projection.json"
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
      "bound approved packet schema artifacts into a materialized registry input",
      "mapped workflow bindings and schema refs for each packet family entry",
      "declared the packet family approval state as APPROVED"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/chatgpt-packet-family-slice.cue",
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
        ref: "schemas/exported/chatgpt-packet-family-slice-input.schema.json",
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
    template_ref: "render/jsonnet/registry/chatgpt-packet-family.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/chatgpt-packet-family.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/chatgpt-packet-family.index.json"

cmp -s "${tmp_dir}/generated/registries/chatgpt-packet-family.index.json" "${repo_root}/${rendered_registry}"

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
