#!/usr/bin/env bash
# Prompt for (or refresh) the local encryption key. Does not commit the key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE=1
fi

if [[ "${FORCE}" -eq 1 ]] && have_key; then
  rm -f "${KEY_FILE}"
fi

prompt_and_store_key "unlock working tree"
echo "repo-crypt: key stored locally at .git/repo-crypt/key (never committed)" >&2

cd "${REPO_ROOT}"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "repo-crypt: decrypting working tree from index..." >&2
  # Re-checkout tracked files so the smudge filter rewrites ciphertext → plaintext.
  while IFS= read -r -d '' f; do
    git checkout -f -- "${f}"
  done < <(git ls-files -z)
  echo "repo-crypt: working tree decrypted" >&2
else
  echo "repo-crypt: no commits yet; key is ready for the first commit" >&2
fi
