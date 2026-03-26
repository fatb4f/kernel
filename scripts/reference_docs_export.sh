#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
out_dir="${repo_root}/$(reference_docs_path_for export "${run_id}")"
report_path="${out_dir}/export-report.json"
source_path="${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}"
schema_path="${repo_root}/${REFERENCE_DOCS_EXPORTED_SCHEMA}"

mkdir -p "${out_dir}"

fragment_ids="$(jq '[.fragments[].name]' "${source_path}")"
fragment_count="$(jq '.fragments | length' "${source_path}")"

jq -n \
  --argjson ids "${fragment_ids}" \
  --arg count "${fragment_count}" \
  '{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "reference-docs-executable-slice-input.schema.json",
    "title": "Reference docs executable slice input",
    "description": "Derived boundary contract for the first executable reference-docs slice.",
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
      "gate_model",
      "render_contract",
      "sections"
    ],
    "properties": {
      "kind": {
        "const": "kernel.reference_docs.slice_input"
      },
      "control_object_id": {
        "const": "reference-docs-executable-slice"
      },
      "source_module_id": {
        "const": "reference-docs-executable-slice"
      },
      "source_module_ref": {
        "const": "structures/core/reference-docs-executable-slice.module.json"
      },
      "export_schema_ref": {
        "const": "schemas/exported/reference-docs-executable-slice-input.schema.json"
      },
      "generator_ref": {
        "const": "manifests/generators/reference-docs-executable-slice.generator.json"
      },
      "projection_ref": {
        "const": "manifests/projections/reference-docs-executable-slice.projection.json"
      },
      "output_path": {
        "const": "generated/docs/reference/executable-slice.md"
      },
      "gate_model": {
        "type": "array",
        "minItems": 6,
        "maxItems": 6,
        "items": {
          "type": "string",
          "enum": ["G1", "G2", "G3", "G4", "G5", "G6"]
        }
      },
      "render_contract": {
        "type": "object",
        "required": ["renderer", "runtime", "runtime_path", "input_class", "output_class"],
        "properties": {
          "renderer": {
            "const": "jsonnet"
          },
          "runtime": {
            "type": "string"
          },
          "runtime_path": {
            "type": "string"
          },
          "input_class": {
            "const": "admitted_state"
          },
          "output_class": {
            "const": "documentation"
          }
        },
        "additionalProperties": false
      },
      "sections": {
        "type": "array",
        "minItems": ($count | tonumber),
        "maxItems": ($count | tonumber),
        "items": {
          "type": "object",
          "required": ["id", "title", "summary", "source_refs"],
          "properties": {
            "id": {
              "type": "string",
              "enum": $ids
            },
            "title": {
              "type": "string"
            },
            "summary": {
              "type": "string"
            },
            "source_refs": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "string"
              }
            }
          },
          "additionalProperties": false
        }
      }
    },
    "additionalProperties": false
  }' >"${schema_path}"

tmp_json="$(mktemp)"
if check-jsonschema --check-metaschema --output-format json "${schema_path}" >"${tmp_json}"; then
  status="PASS"
  reason_codes='[]'
else
  status="FAIL"
  reason_codes='["EXPORT_SCHEMA_INVALID"]'
fi

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg status "${status}" \
  --arg source_ref "${REFERENCE_DOCS_SOURCE_MODULE}" \
  --arg schema_ref "${REFERENCE_DOCS_EXPORTED_SCHEMA}" \
  --arg exported_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson fragment_ids "${fragment_ids}" \
  --slurpfile tool_output "${tmp_json}" \
  --argjson reason_codes "${reason_codes}" \
  '{
    gate: "G2",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: $status,
    source_ref: $source_ref,
    schema_ref: $schema_ref,
    fragment_ids: $fragment_ids,
    exported_at: $exported_at,
    reason_codes: $reason_codes,
    tool: "jq + check-jsonschema",
    tool_output: $tool_output[0]
  }' >"${report_path}"

rm -f "${tmp_json}"

if [[ "${status}" != "PASS" ]]; then
  exit 1
fi
