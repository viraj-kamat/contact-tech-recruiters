#!/usr/bin/env bash
# Git smudge filter: encrypted payload stdin -> plaintext stdout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

RELPATH="${1:-}"
if [[ -z "${RELPATH}" ]]; then
  echo "repo-crypt smudge: missing path argument (%f)" >&2
  exit 1
fi

TMP_IN="$(mktemp)"
TMP_OUT="$(mktemp)"
TMP_B64="$(mktemp)"
trap 'rm -f "${TMP_IN}" "${TMP_OUT}" "${TMP_B64}"' EXIT

cat >"${TMP_IN}"

# If not our payload, leave as-is (fresh files / unencrypted history).
if [[ "$(head -c 10 "${TMP_IN}")" != "${MAGIC}" ]]; then
  cat "${TMP_IN}"
  exit 0
fi

ensure_key "checkout/decrypt"
KEY="$(read_key)"

# Strip magic line, feed remaining base64 to openssl.
tail -n +2 "${TMP_IN}" | tr -d '\n' >"${TMP_B64}"

if ! ENC_PASS="${KEY}" "${OPENSSL_BIN}" enc "-${CIPHER}" -d -md sha256 \
  -pass env:ENC_PASS -a -A -in "${TMP_B64}" -out "${TMP_OUT}" 2>/dev/null; then
  echo "repo-crypt: decryption failed for ${RELPATH} (wrong key?)" >&2
  echo "Clear the cached key with: .gitencrypt/lock.sh" >&2
  echo "Then unlock: .gitencrypt/unlock.sh" >&2
  exit 1
fi

cat "${TMP_OUT}"
