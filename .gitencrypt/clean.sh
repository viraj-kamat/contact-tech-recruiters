#!/usr/bin/env bash
# Git clean filter: plaintext stdin -> encrypted payload on stdout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

RELPATH="${1:-}"
if [[ -z "${RELPATH}" ]]; then
  echo "repo-crypt clean: missing path argument (%f)" >&2
  exit 1
fi

ensure_key "commit/encrypt"
KEY="$(read_key)"
SALT_HEX="$(file_salt_hex "${RELPATH}")"

TMP_IN="$(mktemp)"
TMP_OUT="$(mktemp)"
trap 'rm -f "${TMP_IN}" "${TMP_OUT}"' EXIT

cat >"${TMP_IN}"

# Pass through if already encrypted (re-encrypt would nest).
if [[ "$(head -c 10 "${TMP_IN}")" == "${MAGIC}" ]]; then
  cat "${TMP_IN}"
  exit 0
fi

ENC_PASS="${KEY}" "${OPENSSL_BIN}" enc "-${CIPHER}" -e -md sha256 \
  -pass env:ENC_PASS -S "${SALT_HEX}" -a -A -in "${TMP_IN}" -out "${TMP_OUT}"

# Payload: magic + newline + base64 ciphertext (single line from -A)
{
  printf '%s\n' "${MAGIC}"
  cat "${TMP_OUT}"
  printf '\n'
}
