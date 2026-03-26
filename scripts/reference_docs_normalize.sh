#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
out_dir="${repo_root}/$(reference_docs_path_for normalization "${run_id}")"

mkdir -p "${out_dir}"

jsonnet_bin="$(reference_docs_jsonnet_bin)"

jq -n \
  --argfile source "${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}" \
  --arg runtime_path "${jsonnet_bin}" \
  '{
    kind: "kernel.reference_docs.slice_input",
    control_object_id: "reference-docs-executable-slice",
    source_module_id: $source.id,
    source_module_ref: "structures/core/reference-docs-executable-slice.module.json",
    export_schema_ref: "schemas/exported/reference-docs-executable-slice-input.schema.json",
    generator_ref: "manifests/generators/reference-docs-executable-slice.generator.json",
    projection_ref: "manifests/projections/reference-docs-executable-slice.projection.json",
    output_path: "generated/docs/reference/executable-slice.md",
    gate_model: ["G1", "G2", "G3", "G4", "G5", "G6"],
    render_contract: {
      renderer: "jsonnet",
      runtime: "rsjsonnet",
      runtime_path: $runtime_path,
      input_class: "admitted_state",
      output_class: "documentation"
    },
    sections: [
      $source.fragments[] | {
        id: .name,
        title: (.name | gsub("-"; " ") | split(" ") | map(.[0:1] | ascii_upcase + .[1:]) | join(" ")),
        summary: .description,
        source_refs: (.source_refs // [])
      }
    ]
  }' >"${out_dir}/normalized-state.json"

check-jsonschema \
  --schemafile "${repo_root}/${REFERENCE_DOCS_EXPORTED_SCHEMA}" \
  "${out_dir}/normalized-state.json" >/dev/null

jq -n \
  --argfile source "${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}" \
  '{
    source_module_ref: "structures/core/reference-docs-executable-slice.module.json",
    generator_ref: "manifests/generators/reference-docs-executable-slice.generator.json",
    projection_ref: "manifests/projections/reference-docs-executable-slice.projection.json",
    field_sources: {
      sections: [
        $source.fragments[] | {
          id: .name,
          refs: (.source_refs // [])
        }
      ],
      output_path: [
        "manifests/projections/reference-docs-executable-slice.projection.json"
      ]
    }
  }' >"${out_dir}/source-map.json"

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg normalized_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    gate: "G3",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    normalized_at: $normalized_at,
    operations: [
      "mapped structural fragments to renderer input sections",
      "canonicalized section titles",
      "bound repo-relative output path",
      "recorded source-to-normalized provenance"
    ],
    forbidden_operations_performed: []
  }' >"${out_dir}/normalization-report.json"
