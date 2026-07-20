#!/usr/bin/env bash
# Remove the locally cached encryption key (files stay as currently checked out).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if have_key; then
  rm -f "${KEY_FILE}"
  echo "repo-crypt: local key removed" >&2
else
  echo "repo-crypt: no local key was cached" >&2
fi
