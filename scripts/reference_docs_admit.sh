#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
normalization_dir="${repo_root}/$(reference_docs_path_for normalization "${run_id}")"
admission_dir="${repo_root}/$(reference_docs_path_for admission "${run_id}")"

mkdir -p "${admission_dir}"

normalized_state="${normalization_dir}/normalized-state.json"
cue vet "${repo_root}/${REFERENCE_DOCS_POLICY_BUNDLE}" "${normalized_state}" -d '#Normalized'

jq \
  --arg admitted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {
    admission: {
      decision: "ALLOW",
      policy_bundle_id: "policy/admission/reference-docs-executable-slice.cue",
      admitted_at: $admitted_at
    }
  }' "${normalized_state}" >"${admission_dir}/admitted-state.json"

jq -n >"${admission_dir}/violations.json" '[]'

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg normalized_state_ref "$(realpath --relative-to "${repo_root}" "${normalized_state}")" \
  --arg policy_bundle_id "${REFERENCE_DOCS_POLICY_BUNDLE}" \
  --arg decision_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg cue_version "$(cue version | head -n1)" \
  --arg jq_version "$(jq --version)" \
  --arg normalized_digest "$(sha256sum "${normalized_state}" | awk '{print $1}')" \
  --arg schema_digest "$(sha256sum "${repo_root}/${REFERENCE_DOCS_EXPORTED_SCHEMA}" | awk '{print $1}')" \
  '{
    decision: "ALLOW",
    control_object_id: $control_object_id,
    run_id: $run_id,
    policy_bundle_id: $policy_bundle_id,
    input_digests: {
      normalized_state: {
        ref: $normalized_state_ref,
        algorithm: "sha256",
        value: $normalized_digest
      },
      exported_schema: {
        ref: "schemas/exported/reference-docs-executable-slice-input.schema.json",
        algorithm: "sha256",
        value: $schema_digest
      }
    },
    tool_versions: {
      cue: $cue_version,
      jq: $jq_version
    },
    issued_at: $decision_at
  }' >"${admission_dir}/decision.json"
