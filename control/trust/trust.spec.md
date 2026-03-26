# Trust Spec v1

## 1. Purpose

Define the kernel trust control surface for the ChatGPT packet pipeline.

This spec formalizes a dual-lane trust model:

1. root attestation
2. bundle sign

The root lane authorizes delegated signing authority.
The bundle lane exercises that authority over a concrete bundle payload and its attestation.
The packet lane records the exact trust artifacts a packet depended on during admission.

This document is normative for the trust control surface.

---

## 2. Scope

This spec applies to the trust artifacts under `control/trust/` and the packet-local trust boundary under `generated/packets/<packet_id>/machine/root.trust.evidence.json`.

It does not define the general kernel architecture. That remains governed by `kernel.spec.md` and `kernel.spec.json`.

This spec also does not prescribe a single signing backend. The authority model is kernel-native; the operational bundle-sign implementation may be cosign-based or equivalent, provided it preserves the required artifact contracts and verification order.

---

## 3. Trust Model

### 3.1 Authority split

- The kernel root establishes authority.
- A delegated signer exercises authority within a bounded scope.
- The packet never establishes trust; it only records the trust objects it depends on.

### 3.2 Dual lanes

#### Root attestation lane

Purpose:

- authorize the delegated signer
- constrain signer role and scope
- keep the root key offline
- reserve root use for authorization, rotation, revocation, and trust metadata updates

Outputs:

- root signer set
- root-signed delegation artifact

#### Bundle sign lane

Purpose:

- sign the concrete bundle payload
- attach claims about the bundle contents and validation state

Outputs:

- bundle signature
- bundle attestation

### 3.3 Packet lane

Purpose:

- pin the exact trust artifacts and fingerprints used during admission

Output:

- packet-local `root.trust.evidence.json`

---

## 4. Current Repo Surface

### 4.1 Root signer set

Path:

- `control/trust/root.signers.json`

Current role:

- pinned root trust anchor

Current status:

- signer identity is declared
- signer role is declared
- root public key is materialized in-repo

### 4.2 Delegation artifact

Path:

- `control/trust/delegations/chatgpt.packet-sidecar.json`

Current role:

- shallow kernel delegation for the ChatGPT packet sidecar

Current constraints:

- cannot establish root authority
- cannot mutate root authority
- cannot mutate the root signer set
- cannot self-approve
- cannot broaden delegation scope

### 4.3 Bundle signer delegation

Path:

- `control/trust/delegations/kernel-bundle-signer-001.json`
- `control/trust/delegations/kernel-bundle-signer-001.signature.json`

Current role:

- root-signed delegation for the operational bundle signer

Current status:

- delegated signer identity is declared
- delegated signer public key is materialized
- root signature over the delegation is materialized

### 4.4 Authority manifest

Path:

- `control/scm.pattern/authority.manifest.json`

Current role:

- declare the operational authority surface for the packet pipeline

Current responsibilities:

- precedence
- conflict resolution
- approval basis inputs
- delegated surfaces
- deprecation note

### 4.5 Packet-local trust evidence

Path:

- `generated/packets/<packet_id>/machine/root.trust.evidence.json`

Current role:

- packet-local admission boundary
- reference index for the trust objects and fingerprints the packet depends on

This file does not recreate trust.
It only pins the trust chain used by admission.

---

## 5. Required Artifacts

### 5.1 Root lane artifacts

Required:

- `control/trust/root.signers.json`
- `control/trust/delegations/<signer>.json`

Optional if stored separately:

- `control/trust/delegations/<signer>.signature.json`

### 5.2 Bundle lane artifacts

Required:

- `manifests/bundles/bundle-closure.manifest.json`
- `chatgpt-pipeline.bundle.tgz`
- `chatgpt-pipeline.bundle.tgz.sig`
- `chatgpt-pipeline.bundle.attestation.json`

### 5.3 Packet lane artifacts

Required:

- `generated/packets/<packet_id>/machine/root.trust.evidence.json`

Recommended packet refs:

- `generated/packets/<packet_id>/machine/packet.definition.json`
- `generated/packets/<packet_id>/machine/scm.pattern.binding.json`
- `generated/packets/<packet_id>/machine/packet.review.request.json`
- `generated/packets/<packet_id>/machine/regen.record.json`
- `generated/packets/<packet_id>/machine/artifact.manifest.json`

---

## 6. Artifact Contracts

### 6.1 Root signer set

`control/trust/root.signers.json` must identify the root authority set that is allowed to sign delegations.

Minimum concepts:

- signer identity
- signer algorithm
- public key
- active status
- threshold

### 6.2 Delegation artifact

A delegation artifact must authorize a delegated signer for a bounded role and scope.

Minimum concepts:

- delegate id
- delegate role
- delegated public key
- allowed actions
- allowed targets
- issued by root
- validity window
- active status

### 6.3 Bundle attestation

A bundle attestation must state:

- what bundle was signed
- what digest was signed
- what claims are being made about the bundle
- what trust artifacts those claims depend on

Minimum concepts:

- bundle reference
- bundle fingerprint
- predicate reference, if used
- attested claims
- signer identity
- issuance timestamp

### 6.4 Packet trust evidence

`root.trust.evidence.json` must pin:

- root signer set reference
- delegation reference
- bundle manifest reference
- bundle reference
- bundle signature reference
- bundle attestation reference
- fingerprints for each pinned artifact

The packet evidence file must not invent trust or substitute for root authority.

---

## 7. Verification Order

Admission must verify the chain in this order:

1. Load `control/trust/root.signers.json`.
2. Confirm the expected root public key is present and active.
3. Verify the root-signed delegation.
4. Confirm the delegated signer is authorized for bundle signing and attestation.
5. Verify the bundle signature against the delegated signer key.
6. Verify the bundle attestation signature.
7. Confirm attestation claims match the actual bundle and included refs.
8. Confirm packet-local `root.trust.evidence.json` matches the used trust artifacts.

Admission fails closed if any step fails.

---

## 8. Invariants

1. Root authority stays offline.
2. Root authority is used only for authorization, rotation, revocation, and trust metadata updates.
3. Routine bundle signing is performed only by a delegated signer.
4. Packet-local evidence never establishes trust.
5. The repo must distinguish the closure bundle manifest from the signed bundle payload.
6. Trust artifacts must be explicit and path-stable.
7. Placeholder root key material is not cryptographic trust material.
8. Admission fails closed on missing, stale, or mismatched trust artifacts.

---

## 9. Implementation Status

This spec describes the target trust model and the currently committed control surface.

Current implementation status:

- structural model is defined
- delegation surface exists
- bundle closure selection exists
- packet-local trust evidence exists
- root public key materialization is complete
- root-signed bundle-signer delegation is complete
- bundle signature and bundle attestation artifacts are materialized

The trust objective is therefore structurally represented, with root authority, bundle-signer delegation, bundle signature, and bundle attestation materialized.

---

## 10. Non-Goals

- This spec does not define the full kernel baseline.
- This spec does not define a general-purpose PKI.
- This spec does not require a specific signing backend.
- This spec does not claim the root key is already materialized.
- This spec does not make packet presence equivalent to trust.
