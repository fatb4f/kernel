set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

COSIGN_KEY := "/mnt/admin_vault/kernel-bundle-signer-001/bundle-signer.key"
COSIGN_PUB := "/mnt/admin_vault/kernel-bundle-signer-001/bundle-signer.pub"
BUNDLE_MANIFEST := "manifests/bundles/bundle-closure.manifest.json"

bundle-build MANIFEST=BUNDLE_MANIFEST:
	bash scripts/build_bundle.sh {{MANIFEST}}

bundle-list MANIFEST=BUNDLE_MANIFEST:
	jq -r '.closure_scope.included_paths[]' {{MANIFEST}}

bundle-attest MANIFEST=BUNDLE_MANIFEST BUNDLE='chatgpt-pipeline.bundle.tgz' ATTESTATION='chatgpt-pipeline.bundle.attestation.json':
	bash scripts/build_bundle_attestation.sh {{MANIFEST}} {{BUNDLE}} {{ATTESTATION}}

bundle:
	bash scripts/run_bundle.sh

bundle-pubkey KEY=COSIGN_KEY PUB=COSIGN_PUB:
	COSIGN_PASSWORD='' sudo -E cosign public-key --key {{KEY}} --outfile {{PUB}}

bundle-sign BUNDLE='chatgpt-pipeline.bundle.tgz' SIGNATURE='chatgpt-pipeline.bundle.tgz.sig' BUNDLE_BUNDLE='chatgpt-pipeline.bundle.tgz.bundle' KEY=COSIGN_KEY:
	COSIGN_PASSWORD='' sudo -E cosign sign-blob --new-bundle-format=false --key {{KEY}} --output-signature {{SIGNATURE}} --bundle {{BUNDLE_BUNDLE}} {{BUNDLE}}

bundle-verify BUNDLE='chatgpt-pipeline.bundle.tgz' SIGNATURE='chatgpt-pipeline.bundle.tgz.sig' BUNDLE_BUNDLE='chatgpt-pipeline.bundle.tgz.bundle' PUB=COSIGN_PUB:
	sudo -E cosign verify-blob --key {{PUB}} --bundle {{BUNDLE_BUNDLE}} {{BUNDLE}}

bundle-attest-sign ATTESTATION='chatgpt-pipeline.bundle.attestation.json' SIGNATURE='chatgpt-pipeline.bundle.attestation.json.sig' BUNDLE='chatgpt-pipeline.bundle.attestation.json.bundle' KEY=COSIGN_KEY:
	COSIGN_PASSWORD='' sudo -E cosign sign-blob --new-bundle-format=false --key {{KEY}} --output-signature {{SIGNATURE}} --bundle {{BUNDLE}} {{ATTESTATION}}

bundle-attest-verify ATTESTATION='chatgpt-pipeline.bundle.attestation.json' SIGNATURE='chatgpt-pipeline.bundle.attestation.json.sig' BUNDLE='chatgpt-pipeline.bundle.attestation.json.bundle' PUB=COSIGN_PUB:
	sudo -E cosign verify-blob --key {{PUB}} --bundle {{BUNDLE}} {{ATTESTATION}}

bundle-digest BUNDLE='chatgpt-pipeline.bundle.tgz' ATTESTATION='chatgpt-pipeline.bundle.attestation.json':
	sha256sum {{BUNDLE}} {{ATTESTATION}}

reference-slice-validate RUN_ID='':
	bash scripts/reference_docs_validate.sh {{RUN_ID}}

reference-slice-export RUN_ID='':
	bash scripts/reference_docs_export.sh {{RUN_ID}}

reference-slice-normalize RUN_ID='':
	bash scripts/reference_docs_normalize.sh {{RUN_ID}}

reference-slice-admit RUN_ID='':
	bash scripts/reference_docs_admit.sh {{RUN_ID}}

reference-slice-render RUN_ID='':
	bash scripts/reference_docs_render.sh {{RUN_ID}}

reference-slice-drift RUN_ID='':
	bash scripts/reference_docs_drift.sh {{RUN_ID}}

reference-slice RUN_ID='':
	bash scripts/run_reference_docs_executable_slice.sh {{RUN_ID}}
