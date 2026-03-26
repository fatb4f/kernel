#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/reference_docs_common.sh"

run_id="$(reference_docs_run_id "${1:-}")"

bash "$(dirname "$0")/reference_docs_validate.sh" "${run_id}"
bash "$(dirname "$0")/reference_docs_export.sh" "${run_id}"
bash "$(dirname "$0")/reference_docs_normalize.sh" "${run_id}"
bash "$(dirname "$0")/reference_docs_admit.sh" "${run_id}"
bash "$(dirname "$0")/reference_docs_render.sh" "${run_id}"
bash "$(dirname "$0")/reference_docs_drift.sh" "${run_id}"

printf '%s\n' "${run_id}"
