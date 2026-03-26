#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

repo_root="$(reference_docs_repo_root)"
run_id="$(reference_docs_run_id "${1:-}")"
admission_dir="${repo_root}/$(reference_docs_path_for admission "${run_id}")"
render_dir="${repo_root}/$(reference_docs_path_for render "${run_id}")"
jsonnet_bin="$(reference_docs_jsonnet_bin)"

mkdir -p "${render_dir}"

"${jsonnet_bin}" \
  --multi "${repo_root}" \
  --ext-code-file admitted_state="${admission_dir}/admitted-state.json" \
  "${repo_root}/${REFERENCE_DOCS_RENDER_TEMPLATE}" >/tmp/reference-docs-executable-slice.rendered

jq -n \
  --arg control_object_id "${REFERENCE_DOCS_CONTROL_ID}" \
  --arg run_id "${run_id}" \
  --arg renderer "jsonnet" \
  --arg runtime "rsjsonnet" \
  --arg runtime_path "${jsonnet_bin}" \
  --arg template_ref "${REFERENCE_DOCS_RENDER_TEMPLATE}" \
  --arg admitted_state_ref "$(realpath --relative-to "${repo_root}" "${admission_dir}/admitted-state.json")" \
  --arg rendered_doc "${REFERENCE_DOCS_RENDERED_DOC}" \
  --arg rendered_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    gate: "G5",
    control_object_id: $control_object_id,
    run_id: $run_id,
    status: "PASS",
    renderer: $renderer,
    runtime: $runtime,
    runtime_path: $runtime_path,
    template_ref: $template_ref,
    admitted_state_ref: $admitted_state_ref,
    outputs: [$rendered_doc],
    rendered_at: $rendered_at
  }' >"${render_dir}/render-report.json"

rm -f /tmp/reference-docs-executable-slice.rendered
