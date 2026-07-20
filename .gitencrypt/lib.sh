#!/usr/bin/env bash
# Shared helpers for repo-crypt hooks and filters.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

KEY_DIR="${REPO_ROOT}/.git/repo-crypt"
KEY_FILE="${KEY_DIR}/key"
OWNER_FILE="${KEY_DIR}/owner_pid"
MAGIC="REPOCRYPT1"
CIPHER="aes-256-cbc"
OPENSSL_BIN="${REPO_CRYPT_OPENSSL:-openssl}"

ensure_key_dir() {
  mkdir -p "${KEY_DIR}"
  chmod 700 "${KEY_DIR}" 2>/dev/null || true
}

clear_key() {
  rm -f "${KEY_FILE}" "${OWNER_FILE}"
}

# Key is ephemeral: valid only while the owning git process is still alive.
have_key() {
  if [[ ! -f "${KEY_FILE}" || ! -s "${KEY_FILE}" ]]; then
    return 1
  fi
  if [[ -f "${OWNER_FILE}" ]]; then
    local owner
    owner="$(tr -d '[:space:]' <"${OWNER_FILE}")"
    if [[ -n "${owner}" ]] && ! kill -0 "${owner}" 2>/dev/null; then
      clear_key
      return 1
    fi
  fi
  return 0
}

read_key() {
  if ! have_key; then
    echo "repo-crypt: encryption key not available (enter it when prompted)" >&2
    exit 1
  fi
  local key
  key="$(tr -d '\n' <"${KEY_FILE}")"
  printf '%s' "${key}"
}

# Drop the key once the parent git process exits (covers plain `git add` with no hook).
watch_parent_and_clear_key() {
  local parent="${1:-$PPID}"
  (
    while kill -0 "${parent}" 2>/dev/null; do
      sleep 0.25
    done
    rm -f "${KEY_FILE}" "${OWNER_FILE}"
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

store_key() {
  local key="$1"
  local owner="${2:-$PPID}"
  ensure_key_dir
  printf '%s' "${key}" >"${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
  printf '%s' "${owner}" >"${OWNER_FILE}"
  chmod 600 "${OWNER_FILE}"
  if [[ "${REPO_CRYPT_NO_WATCHDOG:-0}" != "1" ]]; then
    watch_parent_and_clear_key "${owner}"
  fi
}

prompt_and_store_key() {
  local reason="${1:-git operation}"
  ensure_key_dir

  if [[ -n "${REPO_CRYPT_KEY:-}" ]]; then
    store_key "${REPO_CRYPT_KEY}"
    return 0
  fi

  if [[ ! -r /dev/tty ]]; then
    echo "repo-crypt: no TTY to prompt for key during ${reason}." >&2
    echo "Set REPO_CRYPT_KEY for this one command, or run from a terminal." >&2
    exit 1
  fi

  local key
  echo "repo-crypt: enter encryption key (${reason})" >&2
  # Read from /dev/tty so this works when stdin is a pipe (git filters/hooks).
  read -r -s -p "Encryption key: " key </dev/tty
  echo >&2
  if [[ -z "${key}" ]]; then
    echo "repo-crypt: empty key refused" >&2
    exit 1
  fi

  store_key "${key}"
}

# Prompt once per git command; reuse within that command (multi-file add/checkout).
# Never keeps the key after the git process exits.
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
