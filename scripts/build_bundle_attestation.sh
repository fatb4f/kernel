#!/usr/bin/env bash
set -euo pipefail

manifest="${1:-manifests/bundles/bundle-closure.manifest.json}"
bundle="${2:-chatgpt-pipeline.bundle.tgz}"
attestation="${3:-chatgpt-pipeline.bundle.attestation.json}"

if [[ ! -f "$manifest" ]]; then
  printf 'bundle-attest: manifest not found: %s\n' "$manifest" >&2
  exit 1
fi

if [[ ! -f "$bundle" ]]; then
  printf 'bundle-attest: bundle not found: %s\n' "$bundle" >&2
  exit 1
fi

bundle_sha256="$(sha256sum "$bundle" | awk '{print $1}')"
manifest_sha256="$(sha256sum "$manifest" | awk '{print $1}')"
bundle_name="$(jq -r '.bundle_name' "$manifest")"
bundle_path="$(jq -r '.bundle_path' "$manifest")"
bundle_id="$(jq -r '.bundle_id' "$manifest")"
signer_id="$(jq -r '.delegate_id // .bundle_id' control/trust/delegations/kernel-bundle-signer-001.json)"
signer_role="$(jq -r '.delegate_role // "bundle_signer"' control/trust/delegations/kernel-bundle-signer-001.json)"
issued_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg artifact_type "kernel.bundle_attestation" \
  --arg artifact_version "0.1.0" \
  --arg bundle_id "$bundle_id" \
  --arg bundle_name "$bundle_name" \
  --arg bundle_path "$bundle_path" \
  --arg bundle_sha256 "$bundle_sha256" \
  --arg bundle_manifest_ref "$manifest" \
  --arg bundle_manifest_sha256 "$manifest_sha256" \
  --arg signer_id "$signer_id" \
  --arg signer_role "$signer_role" \
  --arg issued_at "$issued_at" \
  --argjson included_paths "$(jq '.closure_scope.included_paths' "$manifest")" \
  --argjson excluded_paths "$(jq '.closure_scope.excluded_paths' "$manifest")" \
  '{
    artifact_type: $artifact_type,
    artifact_version: $artifact_version,
    bundle: {
      bundle_id: $bundle_id,
      bundle_name: $bundle_name,
      bundle_path: $bundle_path,
      bundle_sha256: $bundle_sha256
    },
    bundle_manifest: {
      ref: $bundle_manifest_ref,
      sha256: $bundle_manifest_sha256
    },
    signer: {
      signer_id: $signer_id,
      signer_role: $signer_role
    },
    issued_at: $issued_at,
    claims: {
      included_paths: $included_paths,
      excluded_paths: $excluded_paths,
      bundle_built_from_manifest: true,
      bundle_signing_scope: "bundle_sign",
      predicate_ref: null
    },
    trust_refs: {
      root_signers_ref: "control/trust/root.signers.json",
      bundle_signer_delegation_ref: "control/trust/delegations/kernel-bundle-signer-001.json",
      bundle_signer_delegation_signature_ref: "control/trust/delegations/kernel-bundle-signer-001.signature.json"
    }
  }' > "$attestation"

jq empty "$attestation"
