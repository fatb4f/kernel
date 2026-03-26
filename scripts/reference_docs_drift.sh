#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
admission_dir="${repo_root}/$(reference_docs_path_for admission "${run_id}")"
integrity_dir="${repo_root}/$(reference_docs_path_for integrity "${run_id}")"
jsonnet_bin="$(reference_docs_jsonnet_bin)"

mkdir -p "${integrity_dir}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/generated/docs/reference"

tmp_schema="${tmp_dir}/reference-docs-executable-slice-input.schema.json"
fragment_ids="$(jq '[.fragments[].name]' "${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}")"
fragment_count="$(jq '.fragments | length' "${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}")"

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
  }' >"${tmp_schema}"

if ! cmp -s "${tmp_schema}" "${repo_root}/${REFERENCE_DOCS_EXPORTED_SCHEMA}"; then
  printf '%s\n' "Exported schema drift detected" >&2
  exit 1
fi

"${jsonnet_bin}" \
  --string \
  --output-file "${tmp_dir}/${REFERENCE_DOCS_RENDERED_DOC}" \
  --ext-code-file admitted_state="${admission_dir}/admitted-state.json" \
  "${repo_root}/${REFERENCE_DOCS_RENDER_TEMPLATE}"

if ! cmp -s "${tmp_dir}/${REFERENCE_DOCS_RENDERED_DOC}" "${repo_root}/${REFERENCE_DOCS_RENDERED_DOC}"; then
  printf '%s\n' "Rendered documentation drift detected" >&2
  exit 1
fi

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    gate: "G6",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    checked_at: $checked_at,
    checks: [
      "exported schema regenerates without drift",
      "rendered documentation regenerates without drift",
      "required generated outputs are present"
    ]
  }' >"${integrity_dir}/drift-report.json"
