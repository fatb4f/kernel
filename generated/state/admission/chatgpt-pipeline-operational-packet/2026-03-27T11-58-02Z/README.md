# ChatGPT pipeline operational packet

This bundle closes the missing authority instance and required packet artifacts for the collapsed ChatGPT-owned generation path.

## Contents
- `pipeline/` — ingress, execution, validation, and gate policy
- `schemas/` — packet and authority schemas
- `control/` — authority and trust material
- `generated/problem_sets/ps-operationalize-chatgpt-pipeline-001/problem_set.json` — concrete ingress example
- `generated/packets/pkt-operational-chatgpt-pipeline-001/` — required machine and human packet artifacts
- `local_runtime/validate_and_admit.py` — local validator/admission runner

## Run
```bash
python local_runtime/validate_and_admit.py generated/packets/pkt-operational-chatgpt-pipeline-001
```

Expected outcome:
- admission: PASS
- review gate: PASS
- realization gate: WAITING_HUMAN_REVIEW
