#!/usr/bin/env bash
# Shared helpers for repo-crypt hooks and filters.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

KEY_FILE="${REPO_ROOT}/.git/repo-crypt/key"
MAGIC="REPOCRYPT1"
CIPHER="aes-256-cbc"
OPENSSL_BIN="${REPO_CRYPT_OPENSSL:-openssl}"

ensure_key_dir() {
  mkdir -p "$(dirname "${KEY_FILE}")"
  chmod 700 "$(dirname "${KEY_FILE}")" 2>/dev/null || true
}

have_key() {
  [[ -f "${KEY_FILE}" && -s "${KEY_FILE}" ]]
}

read_key() {
  if ! have_key; then
    echo "repo-crypt: encryption key not set. Run: .gitencrypt/setup.sh" >&2
    exit 1
  fi
  # Trim a single trailing newline if present; otherwise keep exact bytes.
  local key
  key="$(tr -d '\n' <"${KEY_FILE}")"
  printf '%s' "${key}"
}

prompt_and_store_key() {
  local reason="${1:-git operation}"
  ensure_key_dir

  if [[ ! -t 0 && -z "${REPO_CRYPT_KEY:-}" ]]; then
    # Non-interactive: allow env override for CI/scripts, otherwise fail clearly.
    if have_key; then
      return 0
    fi
    echo "repo-crypt: no TTY to prompt for key during ${reason}." >&2
    echo "Set REPO_CRYPT_KEY in the environment, or run: .gitencrypt/unlock.sh" >&2
    exit 1
  fi

  if [[ -n "${REPO_CRYPT_KEY:-}" ]]; then
    printf '%s' "${REPO_CRYPT_KEY}" >"${KEY_FILE}"
    chmod 600 "${KEY_FILE}"
    return 0
  fi

  local key key2
  echo "repo-crypt: enter symmetric encryption key (${reason})" >&2
  # Read from /dev/tty so this works when stdin is a pipe (git filters/hooks).
  read -r -s -p "Encryption key: " key </dev/tty
  echo >&2
  if [[ -z "${key}" ]]; then
    echo "repo-crypt: empty key refused" >&2
    exit 1
  fi

  if ! have_key; then
    read -r -s -p "Confirm key: " key2 </dev/tty
    echo >&2
    if [[ "${key}" != "${key2}" ]]; then
      echo "repo-crypt: keys do not match" >&2
      exit 1
    fi
  fi

  printf '%s' "${key}" >"${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
}

ensure_key() {
  local reason="${1:-git operation}"
  if have_key; then
    return 0
  fi
  prompt_and_store_key "${reason}"
}

# 8-byte OpenSSL salt derived from key + relative path (deterministic per file).
file_salt_hex() {
  local relpath="$1"
  local key
  key="$(read_key)"
  printf '%s' "${key}:${relpath}" | "${OPENSSL_BIN}" dgst -sha256 -binary | xxd -p -c 256 | cut -c1-16
}

filter_configured() {
  git config --get filter.repo-crypt.clean >/dev/null 2>&1
}
