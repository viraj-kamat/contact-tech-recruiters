#!/usr/bin/env bash
# Prompt for the key, force-decrypt the working tree, then forget the key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

cd "${REPO_ROOT}"

if ! filter_configured; then
  echo "repo-crypt: filters not configured. Run: .gitencrypt/setup.sh" >&2
  exit 1
fi

clear_key
REPO_CRYPT_NO_WATCHDOG=1 prompt_and_store_key "unlock working tree"

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  clear_key
  echo "repo-crypt: no commits yet" >&2
  exit 0
fi

echo "repo-crypt: decrypting working tree..." >&2

# Disable hooks for this reset so post-checkout doesn't wipe the key mid-decrypt.
# reset --hard always rewrites the worktree through the smudge filter (unlike
# checkout when the worktree already matches the encrypted index blob after clone).
EMPTY_HOOKS="$(mktemp -d)"
trap 'rm -rf "${EMPTY_HOOKS}"; clear_key' EXIT

if ! git -c core.hooksPath="${EMPTY_HOOKS}" reset --hard HEAD; then
  echo "repo-crypt: decrypt failed (wrong key?)" >&2
  exit 1
fi

# Spot-check: a non-exempt tracked file should no longer start with the magic header.
sample=""
while IFS= read -r -d '' f; do
  case "${f}" in
    .gitattributes|.gitignore|.gitencrypt/*|.githooks/*) continue ;;
  esac
  if [[ -f "${f}" ]]; then
    sample="${f}"
    break
  fi
done < <(git ls-files -z)

if [[ -n "${sample}" && "$(head -c 10 "${sample}")" == "${MAGIC}" ]]; then
  echo "repo-crypt: ${sample} is still ciphertext — wrong key or filters not applied." >&2
  exit 1
fi

clear_key
trap - EXIT
rm -rf "${EMPTY_HOOKS}"

echo "repo-crypt: working tree decrypted" >&2
echo "repo-crypt: key cleared (you will be prompted again on the next git command)" >&2
