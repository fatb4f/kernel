#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]

SCHEMA_MAP = {
    'packet.definition.json': 'schemas/chatgpt-packet/packet.definition.schema.json',
    'scm.pattern.binding.json': 'schemas/chatgpt-packet/scm.pattern.binding.schema.json',
    'packet.review.request.json': 'schemas/chatgpt-packet/packet.review.request.schema.json',
    'root.trust.evidence.json': 'schemas/chatgpt-packet/root.trust.evidence.schema.json',
    'regen.record.json': 'schemas/chatgpt-packet/regen.record.schema.json',
    'artifact.manifest.json': 'schemas/chatgpt-packet/artifact.manifest.schema.json',
    'packet.approval.json': 'schemas/chatgpt-packet/packet.approval.schema.json',
}


def load_json(path: Path):
    with path.open() as f:
        return json.load(f)


def sha256_path(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ensure_repo_relative(ref: str):
    p = Path(ref)
    if p.is_absolute() or '..' in p.parts:
        raise ValueError(f'Non repo-relative ref: {ref}')


def validate_json(instance_path: Path, schema_path: Path):
    schema = load_json(schema_path)
    instance = load_json(instance_path)
    Draft202012Validator(schema).validate(instance)


def verify_authority(root: Path):
    authority = root / 'control/scm.pattern/authority.manifest.json'
    schema = root / 'schemas/control/scm.pattern/authority.manifest.schema.json'
    validate_json(authority, schema)
    validation_doc = load_json(root / 'control/scm.pattern/authority.manifest.validation.json')
    signature_doc = load_json(root / 'control/scm.pattern/authority.manifest.signature.json')
    root_signers = load_json(root / 'control/trust/root.signers.json')
    signer_ids = {s['signer_id'] for s in root_signers['signers']}
    manifest_digest = sha256_path(authority)
    if validation_doc['manifest_fingerprint']['value'] != manifest_digest:
        raise ValueError('Authority validation fingerprint mismatch')
    if signature_doc['manifest_fingerprint']['value'] != manifest_digest:
        raise ValueError('Authority signature fingerprint mismatch')
    if signature_doc['signer_id'] not in signer_ids:
        raise ValueError('Authority signer is not trusted')


def verify_root_trust(root: Path, packet_machine: Path):
    evidence = load_json(packet_machine / 'root.trust.evidence.json')
    keymap = {
        'root_signers': 'control/trust/root.signers.json',
        'authority_manifest': 'control/scm.pattern/authority.manifest.json',
        'authority_manifest_validation': 'control/scm.pattern/authority.manifest.validation.json',
        'authority_manifest_signature': 'control/scm.pattern/authority.manifest.signature.json',
        'delegation': 'control/trust/delegations/chatgpt.packet-sidecar.json',
    }
    for key, rel in keymap.items():
        actual = sha256_path(root / rel)
        declared = evidence['canonical_fingerprints'][key]['value']
        if actual != declared:
            raise ValueError(f'Root trust fingerprint mismatch for {key}')


def verify_refs(root: Path, refs):
    for ref in refs:
        ensure_repo_relative(ref)
        if not (root / ref).exists():
            raise FileNotFoundError(ref)


def verify_manifest_and_regen(root: Path, packet_root: Path):
    machine = packet_root / 'machine'
    manifest = load_json(machine / 'artifact.manifest.json')
    for artifact in manifest['required_artifacts']:
        verify_refs(root, [artifact['ref']])
    conditional = manifest.get('conditional_artifacts', [])
    for artifact in conditional:
        ensure_repo_relative(artifact['ref'])
    regen = load_json(machine / 'regen.record.json')
    for name, declared in regen['output_fingerprints'].items():
        candidate = None
        for p in list(machine.glob('*')) + list((packet_root / 'human').glob('*')):
            if p.name == name:
                candidate = p
                break
        if candidate is None:
            raise FileNotFoundError(name)
        actual = sha256_path(candidate)
        if actual != declared:
            raise ValueError(f'Output fingerprint mismatch for {name}')


def verify_gate_state(root: Path, packet_root: Path):
    machine = packet_root / 'machine'
    approval = load_json(machine / 'packet.approval.json')
    if approval['approval_authority']:
        raise ValueError('packet.approval.json must remain non-authoritative')
    decision_path = machine / 'packet.review.decision.json'
    if decision_path.exists():
        decision = load_json(decision_path)
        if not decision.get('approval_authority', False):
            raise ValueError('Existing review decision is not authoritative')
        return 'READY_FOR_REALIZATION'
    return 'WAITING_HUMAN_REVIEW'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('packet_root', nargs='?', default='generated/packets/pkt-operational-chatgpt-pipeline-001')
    args = ap.parse_args()
    packet_root = ROOT / args.packet_root
    machine = packet_root / 'machine'
    human = packet_root / 'human'

    verify_authority(ROOT)
    validate_json(ROOT / 'generated/problem_sets/ps-operationalize-chatgpt-pipeline-001/problem_set.json', ROOT / 'pipeline/problem_set.schema.json')
    for filename, schema_rel in SCHEMA_MAP.items():
        validate_json(machine / filename, ROOT / schema_rel)
    verify_root_trust(ROOT, machine)

    packet_def = load_json(machine / 'packet.definition.json')
    refs = [i['ref'] for i in packet_def['inputs']]
    refs += [d['ref'] for d in packet_def['deliverables']['required_now']]
    refs += [packet_def['kernel_trust_requirements'][k] for k in packet_def['kernel_trust_requirements'] if k.endswith('_ref')]
    verify_refs(ROOT, refs)
    verify_manifest_and_regen(ROOT, packet_root)

    human_text = (human / 'packet.definition.md').read_text()
    if packet_def['title'] not in human_text or packet_def['summary'] not in human_text:
        raise ValueError('Human markdown contradicts packet definition')

    realization = verify_gate_state(ROOT, packet_root)
    result = {
        'packet_id': packet_def['packet_id'],
        'admission': 'PASS',
        'review_gate': 'PASS',
        'realization_gate': realization,
        'next_step': 'Issue packet.review.decision.json externally to unlock realization.' if realization == 'WAITING_HUMAN_REVIEW' else 'Local runtime may realize through scm.pattern.'
    }
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
