#!/usr/bin/env bash
# Remove any ephemeral encryption key left behind.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

clear_key
echo "repo-crypt: local key cleared" >&2
