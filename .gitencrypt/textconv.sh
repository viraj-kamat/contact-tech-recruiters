#!/usr/bin/env bash
# textconv helper: decrypt a blob file for git diff when possible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

FILE="${1:-}"
if [[ -z "${FILE}" || ! -f "${FILE}" ]]; then
  exit 0
fi

if [[ "$(head -c 10 "${FILE}")" != "${MAGIC}" ]]; then
  cat "${FILE}"
  exit 0
fi

if ! have_key; then
  # Diff without a key: show encrypted marker rather than failing the whole diff.
  echo "[repo-crypt: encrypted — run .gitencrypt/unlock.sh to view plaintext]"
  exit 0
fi

KEY="$(read_key)"
TMP_OUT="$(mktemp)"
trap 'rm -f "${TMP_OUT}"' EXIT

if ! tail -n +2 "${FILE}" | tr -d '\n' | \
  ENC_PASS="${KEY}" "${OPENSSL_BIN}" enc "-${CIPHER}" -d -md sha256 \
    -pass env:ENC_PASS -a -A -out "${TMP_OUT}" 2>/dev/null; then
  echo "[repo-crypt: decryption failed — wrong key?]"
  exit 0
fi

cat "${TMP_OUT}"
