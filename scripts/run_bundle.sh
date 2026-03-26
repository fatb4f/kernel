#!/usr/bin/env bash
set -euo pipefail

just bundle-build
just bundle-attest
just bundle-pubkey
just bundle-sign
just bundle-verify
just bundle-attest-sign
just bundle-attest-verify

just bundle-digest
