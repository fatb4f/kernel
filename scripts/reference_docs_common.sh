#!/usr/bin/env bash

set -euo pipefail

REFERENCE_DOCS_CONTROL_ID="reference-docs-executable-slice"
REFERENCE_DOCS_SOURCE_MODULE="structures/core/reference-docs-executable-slice.module.json"
REFERENCE_DOCS_GENERATOR_MANIFEST="manifests/generators/reference-docs-executable-slice.generator.json"
REFERENCE_DOCS_PROJECTION_MANIFEST="manifests/projections/reference-docs-executable-slice.projection.json"
REFERENCE_DOCS_SOURCE_SCHEMA="schemas/exported/canonical-structure-family.schema.json"
REFERENCE_DOCS_EXPORTED_SCHEMA="schemas/exported/reference-docs-executable-slice-input.schema.json"
REFERENCE_DOCS_RENDER_TEMPLATE="render/jsonnet/reference/executable-slice.jsonnet"
REFERENCE_DOCS_RENDERED_DOC="generated/docs/reference/executable-slice.md"
REFERENCE_DOCS_POLICY_BUNDLE="policy/admission/reference-docs-executable-slice.cue"

reference_docs_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

reference_docs_run_id() {
  if [[ $# -gt 0 && -n "${1}" ]]; then
    printf '%s\n' "${1}"
  else
    date -u +%Y-%m-%dT%H-%M-%SZ
  fi
}

reference_docs_jsonnet_bin() {
  if command -v rsjsonnet >/dev/null 2>&1; then
    command -v rsjsonnet
    return
  fi

  if [[ -x "${HOME}/.local/share/cargo/bin/rsjsonnet" ]]; then
    printf '%s\n' "${HOME}/.local/share/cargo/bin/rsjsonnet"
    return
  fi

  printf '%s\n' "rsjsonnet not found" >&2
  return 1
}

reference_docs_path_for() {
  local phase="${1}"
  local run_id="${2}"
  printf '%s/%s/%s\n' "generated/state/${phase}" "${REFERENCE_DOCS_CONTROL_ID}" "${run_id}"
}
