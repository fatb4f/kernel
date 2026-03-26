#!/usr/bin/env bash
set -euo pipefail

manifest="${1:-manifests/bundles/bundle-closure.manifest.json}"

if [[ ! -f "$manifest" ]]; then
  printf 'bundle-build: manifest not found: %s\n' "$manifest" >&2
  exit 1
fi

shopt -s globstar nullglob dotglob

bundle_path="$(jq -r '.bundle_path' "$manifest")"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r pattern; do
  matches=( $pattern )
  if (( ${#matches[@]} == 0 )); then
    printf 'bundle-build: no matches for pattern %s\n' "$pattern" >&2
    exit 1
  fi
  printf '%s\n' "${matches[@]}" >> "$tmp"
done < <(jq -r '.closure_scope.included_paths[]' "$manifest")

sort -u "$tmp" -o "$tmp"
tar -czf "$bundle_path" --files-from "$tmp"
