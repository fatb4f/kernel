#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
out_dir="${repo_root}/$(reference_docs_path_for source-validation "${run_id}")"
report_path="${out_dir}/source-validation.json"

mkdir -p "${out_dir}"

tmp_json="$(mktemp)"
if check-jsonschema --schemafile "${repo_root}/${REFERENCE_DOCS_SOURCE_SCHEMA}" --output-format json "${repo_root}/${REFERENCE_DOCS_SOURCE_MODULE}" >"${tmp_json}"; then
  status="PASS"
  reason_codes='[]'
else
  status="FAIL"
  reason_codes='["SRC_SCHEMA_VALIDATION_FAILED"]'
fi

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg status "${status}" \
  --arg schema_ref "${REFERENCE_DOCS_SOURCE_SCHEMA}" \
  --arg instance_ref "${REFERENCE_DOCS_SOURCE_MODULE}" \
  --arg validated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argfile tool_output "${tmp_json}" \
  --argjson reason_codes "${reason_codes}" \
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
    tool_output: $tool_output
  }' >"${report_path}"

rm -f "${tmp_json}"

if [[ "${status}" != "PASS" ]]; then
  exit 1
fi
