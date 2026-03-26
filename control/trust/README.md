# Trust Model

This document describes the kernel trust objective and the currently committed trust surface.

The canonical spec for this surface is [trust.spec.md](./trust.spec.md).

It is intentionally split into:

1. the trust objective we want
2. the implemented repo surface we have now
3. the missing key material and future trust-chain work

---

## Trust Objective

The kernel owns trust.

The ChatGPT packet sidecar does not establish authority. It only consumes delegated trust and emits packet artifacts within the scope the kernel grants.

The intended operational shape is:

- kernel root key stays offline
- root public key is pinned in kernel
- kernel signs a delegation that authorizes the operational sidecar scope
- packet-local artifacts reference the exact trust objects they depend on
- local tooling validates and admits artifacts before realization

That is the objective. It is clearly represented in the repo, but not fully instantiated cryptographically yet.

---

## Current Committed Surface

### `control/trust/root.signers.json`

This is the pinned root signer set for the kernel authority surface.

Current status:

- signer identity is declared
- algorithm is declared
- `public_key` is still a placeholder
- therefore the kernel root key is not yet materialized in-repo

### `control/trust/delegations/chatgpt.packet-sidecar.json`

This is the current delegation artifact.

It grants the ChatGPT packet sidecar a shallow scope over packet artifact generation only.

Important constraints in the current file:

- it does not grant root authority
- it cannot mutate the root signer set
- it cannot self-approve
- it cannot broaden its own scope

### `control/scm.pattern/authority.manifest.json`

This is the current authority surface for the operational ChatGPT packet pipeline.

It defines:

- precedence
- conflict resolution
- approval basis inputs
- delegated surfaces
- deprecation note for the shallow sidecar model

### `generated/packets/pkt-kernel-chain-of-trust-001/machine/root.trust.evidence.json`

This packet-local artifact records the trust boundary the packet depends on.

It does not recreate trust. It just pins the references and fingerprints that the packet expects.

Current status:

- structurally valid
- uses placeholder fingerprint values
- explicitly records the root key as unresolved

---

## What Is Not Yet Implemented

The following are still future work:

- a real kernel root public key in `control/trust/root.signers.json`
- a real signed delegation payload instead of placeholders
- materialized validation attestation signatures for the authority surface
- any additional schema-validator trust chain beyond the current packet-sidecar delegation

There is no committed `schema-validator` key chain in this repo right now.
If that becomes part of the plan later, it should be added explicitly rather than implied by this README.

---

## How To Read The Repo

Use the current files this way:

- `root.signers.json` defines the trust root identity surface
- `chatgpt.packet-sidecar.json` defines the delegated operational scope
- `authority.manifest.json` defines what the sidecar may treat as authoritative for packet authoring
- `root.trust.evidence.json` records what the packet depends on

Do not read the placeholder values as live cryptographic material.
They are planning and structural markers only.

---

## Future Trust Chain

If and when the kernel root key is materialized, the next step is to replace the placeholders with real values and, if needed, add signed validation artifacts for authority-manifest review.

That future chain should remain shallow:

- kernel root signs delegation
- delegated scope covers packet-sidecar work only
- packet-local evidence points back to the kernel-owned trust objects
- local tooling enforces admission before realization

Until then, this directory is a trust model and control surface, not a completed cryptographic trust deployment.
