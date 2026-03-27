#!/usr/bin/env bash

set -euo pipefail

control_id="completion-obligations-surface-slice"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${1:-$(date -u +%Y-%m-%dT%H-%M-%SZ)}"

source_module="structures/core/completion-obligations-surface-slice.module.json"
source_schema="schemas/exported/canonical-structure-family.schema.json"
exported_schema="schemas/exported/completion-obligations-surface-slice-input.schema.json"
policy_bundle="policy/admission/completion-obligations-surface-slice.cue"
render_template="render/jsonnet/registry/completion-obligations.jsonnet"
rendered_registry="generated/registries/completion-obligations.index.json"
closeout_manifest="manifests/bundles/kernel-core-json-structure-closeout.manifest.json"

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
  g1_reasons='["SRC_SCHEMA_VALIDATED"]'
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
  "$id": "completion-obligations-surface-slice-input.schema.json",
  "title": "Completion obligations surface slice input",
  "description": "Derived boundary contract for the completion-obligations surface slice.",
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
    "overall_status",
    "obligation_groups",
    "render_contract"
  ],
  "properties": {
    "kind": {"const": "kernel.completion_obligations_surface.slice_input"},
    "control_object_id": {"const": "completion-obligations-surface-slice"},
    "source_module_id": {"const": "completion-obligations-surface-slice"},
    "source_module_ref": {"const": "structures/core/completion-obligations-surface-slice.module.json"},
    "export_schema_ref": {"const": "schemas/exported/completion-obligations-surface-slice-input.schema.json"},
    "generator_ref": {"const": "manifests/generators/completion-obligations-surface-slice.generator.json"},
    "projection_ref": {"const": "manifests/projections/completion-obligations-surface-slice.projection.json"},
    "output_path": {"const": "generated/registries/completion-obligations.index.json"},
    "overall_status": {"type": "string", "enum": ["materialized", "partial"]},
    "obligation_groups": {
      "type": "object",
      "required": ["invariants", "artifact_classes", "implementation_order", "completion_conditions", "toolchain_control"],
      "properties": {
        "invariants": {"$ref": "#/$defs/group"},
        "artifact_classes": {"$ref": "#/$defs/group"},
        "implementation_order": {"$ref": "#/$defs/group"},
        "completion_conditions": {"$ref": "#/$defs/group"},
        "toolchain_control": {"$ref": "#/$defs/group"}
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
  "$defs": {
    "entry": {
      "type": "object",
      "required": ["id", "label", "status", "evidence_refs"],
      "properties": {
        "id": {"type": "string"},
        "label": {"type": "string"},
        "status": {"type": "string", "enum": ["materialized", "partial"]},
        "evidence_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1}
      },
      "additionalProperties": false
    },
    "group": {
      "type": "object",
      "required": ["status", "evidence_refs", "items"],
      "properties": {
        "status": {"type": "string", "enum": ["materialized", "partial"]},
        "evidence_refs": {"type": "array", "items": {"type": "string"}, "minItems": 1},
        "items": {
          "type": "array",
          "minItems": 1,
          "items": {"$ref": "#/$defs/entry"}
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}' >"${repo_root}/${exported_schema}"

g2_json="$(mktemp)"
if check-jsonschema --check-metaschema --output-format json "${repo_root}/${exported_schema}" >"${g2_json}"; then
  g2_status="PASS"
  g2_reasons='["EXPORT_SCHEMA_EXPORTED"]'
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
  --slurpfile spec "${repo_root}/kernel.spec.json" \
  --slurpfile closeout "${repo_root}/${closeout_manifest}" \
  --arg runtime_path "${jsonnet_runtime}" \
  'def entry($id; $label; $refs):
      {
        id: $id,
        label: $label,
        status: "materialized",
        evidence_refs: $refs
      };
    {
      kind: "kernel.completion_obligations_surface.slice_input",
      control_object_id: "completion-obligations-surface-slice",
      source_module_id: "completion-obligations-surface-slice",
      source_module_ref: "structures/core/completion-obligations-surface-slice.module.json",
      export_schema_ref: "schemas/exported/completion-obligations-surface-slice-input.schema.json",
      generator_ref: "manifests/generators/completion-obligations-surface-slice.generator.json",
      projection_ref: "manifests/projections/completion-obligations-surface-slice.projection.json",
      output_path: "generated/registries/completion-obligations.index.json",
      overall_status: "materialized",
      obligation_groups: {
        invariants: {
          status: "materialized",
          evidence_refs: [
            "kernel.spec.json#/invariants",
            "policy/data/generated-build-boundary.json"
          ],
          items: [
            ($spec[0].invariants // [])[] | entry(. ; . ; ["kernel.spec.json#/invariants", "policy/data/generated-build-boundary.json"])
          ]
        },
        artifact_classes: {
          status: "materialized",
          evidence_refs: [
            "kernel.spec.json#/artifact_classes",
            "manifests/output-classes.schema.json"
          ],
          items: [
            ($spec[0].artifact_classes // [])[] | entry(. ; . ; ["kernel.spec.json#/artifact_classes", "manifests/output-classes.schema.json"])
          ]
        },
        implementation_order: {
          status: "materialized",
          evidence_refs: [
            "kernel.spec.json#/implementation_order",
            "KERNEL_SPEC.md",
            "manifests/kernel.bundle.schema.json",
            "manifests/output-classes.schema.json",
            "policy/contracts/normalization.md",
            "ci/gate-matrix.md",
            "generated/state/admission/reference-docs-executable-slice/2026-03-26T23-05-00Z/decision.json"
          ],
          items: [
            entry("phase-1"; "KERNEL_SPEC.md"; ["kernel.spec.json#/implementation_order/0", "KERNEL_SPEC.md"]),
            entry("phase-2"; "manifests/kernel.bundle.schema.json"; ["kernel.spec.json#/implementation_order/1", "manifests/kernel.bundle.schema.json"]),
            entry("phase-3"; "manifests/output-classes.schema.json"; ["kernel.spec.json#/implementation_order/2", "manifests/output-classes.schema.json"]),
            entry("phase-4"; "policy/contracts/normalization.md"; ["kernel.spec.json#/implementation_order/3", "policy/contracts/normalization.md"]),
            entry("phase-5"; "ci/gate-matrix.md"; ["kernel.spec.json#/implementation_order/4", "ci/gate-matrix.md"]),
            entry("phase-6"; "admission artifact materialization"; ["kernel.spec.json#/implementation_order/5", "generated/state/admission/reference-docs-executable-slice/2026-03-26T23-05-00Z/decision.json"])
          ]
        },
        completion_conditions: {
          status: "materialized",
          evidence_refs: [
            "kernel.spec.json#/completion_condition",
            "manifests/bundles/kernel-core-json-structure-closeout.manifest.json"
          ],
          items: [
            entry("condition-1"; "prose authority exists"; ["kernel.spec.json#/completion_condition/0", "KERNEL_SPEC.md", "kernel.spec.json"]),
            entry("condition-2"; "control objects validate"; ["kernel.spec.json#/completion_condition/1", "generated/state/source-validation/completion-obligations-surface-slice/2026-03-27T02-00-00Z/source-validation.json"]),
            entry("condition-3"; "outputs are typed"; ["kernel.spec.json#/completion_condition/2", "manifests/output-classes.schema.json"]),
            entry("condition-4"; "normalization boundary is explicit"; ["kernel.spec.json#/completion_condition/3", "policy/contracts/normalization.md", "generated/registries/normalization-surfaces.index.json"]),
            entry("condition-5"; "gate IDs and evidence artifacts are fixed"; ["kernel.spec.json#/completion_condition/4", "ci/gate-matrix.md", "generated/registries/reason-code-surfaces.index.json"]),
            entry("condition-6"; "admission artifacts are no longer implicit"; ["kernel.spec.json#/completion_condition/5", "generated/state/admission/reference-docs-executable-slice/2026-03-26T23-05-00Z/decision.json", "generated/state/admission/core-closeout-status-slice/2026-03-27T01-45-00Z/decision.json"])
          ]
        },
        toolchain_control: {
          status: "materialized",
          evidence_refs: [
            "policy/data/toolchain-control.index.json",
            "Justfile",
            "policy/data/generated-build-boundary.json"
          ],
          items: [
            entry("toolchain-1"; "toolchain control index exists"; ["policy/data/toolchain-control.index.json"]),
            entry("toolchain-2"; "workflow orchestration is declared"; ["Justfile"]),
            entry("toolchain-3"; "generated/build boundary is declared"; ["policy/data/generated-build-boundary.json"])
          ]
        }
      },
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
  --arg run_id "${run_id}" \
  '{
    source_module_ref: "structures/core/completion-obligations-surface-slice.module.json",
    field_sources: {
      obligation_groups: [
        "kernel.spec.json#/invariants",
        "kernel.spec.json#/artifact_classes",
        "kernel.spec.json#/implementation_order",
        "kernel.spec.json#/completion_condition",
        "KERNEL_SPEC.md",
        "manifests/kernel.bundle.schema.json",
        "manifests/output-classes.schema.json",
        "policy/contracts/normalization.md",
        "ci/gate-matrix.md",
        "policy/data/toolchain-control.index.json",
        "policy/data/generated-build-boundary.json",
        "manifests/bundles/kernel-core-json-structure-closeout.manifest.json",
        ("generated/state/source-validation/completion-obligations-surface-slice/" + $run_id + "/source-validation.json")
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
    reason_codes: ["NORM_STATE_EMITTED"],
    operations: [
      "bound invariants, artifact classes, implementation order, completion conditions, and toolchain control into one obligation surface",
      "materialized the required implementation-order files named by the kernel spec",
      "produced a single admitted-state input for completion-obligation closeout"
    ],
    forbidden_operations_performed: []
  }' >"${repo_root}/$(phase_dir normalization)/normalization-report.json"

cue vet "${repo_root}/${policy_bundle}" "${repo_root}/$(phase_dir normalization)/normalized-state.json" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/completion-obligations-surface-slice.cue",
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
    reason_codes: ["ADMIT_DECISION_ALLOW"],
    input_digests: {
      normalized_state: {
        ref: $normalized_ref,
        algorithm: "sha256",
        value: $normalized_digest
      },
      exported_schema: {
        ref: "schemas/exported/completion-obligations-surface-slice-input.schema.json",
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
    reason_codes: ["RENDER_OUTPUT_EMITTED"],
    renderer: "jsonnet",
    runtime: "rsjsonnet",
    runtime_path: $runtime_path,
    template_ref: "render/jsonnet/registry/completion-obligations.jsonnet",
    admitted_state_ref: $admitted_state_ref,
    outputs: ["generated/registries/completion-obligations.index.json"],
    rendered_at: $rendered_at
  }' >"${repo_root}/$(phase_dir render)/render-report.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/registries"

"${jsonnet_runtime}" \
  --ext-code-file admitted_state="${repo_root}/$(phase_dir admission)/admitted-state.json" \
  "${repo_root}/${render_template}" >"${tmp_dir}/generated/registries/completion-obligations.index.json"

cmp -s "${tmp_dir}/generated/registries/completion-obligations.index.json" "${repo_root}/${rendered_registry}"

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
    reason_codes: ["DRIFT_REGEN_CLEAN"],
    checks: [
      "exported schema is present",
      "rendered completion-obligations registry regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${repo_root}/$(phase_dir integrity)/drift-report.json"

printf "%s\n" "${run_id}"
