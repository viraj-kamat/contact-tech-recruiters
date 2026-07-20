#!/usr/bin/env bash
# Prompt for the key, decrypt the working tree, then forget the key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

clear_key
REPO_CRYPT_NO_WATCHDOG=1 prompt_and_store_key "unlock working tree"

cd "${REPO_ROOT}"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "repo-crypt: decrypting working tree from index..." >&2
  while IFS= read -r -d '' f; do
    git checkout -f -- "${f}"
  done < <(git ls-files -z)
  echo "repo-crypt: working tree decrypted" >&2
else
  echo "repo-crypt: no commits yet" >&2
fi

clear_key
echo "repo-crypt: key cleared (you will be prompted again on the next git command)" >&2
