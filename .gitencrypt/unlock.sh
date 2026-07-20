#!/usr/bin/env bash
# Prompt for the key, force-decrypt the working tree, then forget the key.
#
# IMPORTANT: After a normal `git clone`, the worktree already contains the
# encrypted blobs. `git reset --hard` / `git checkout` will NOT re-run the
# smudge filter in that case. We must decrypt by reading each blob and
# piping it through smudge ourselves.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

cd "${REPO_ROOT}"

is_exempt() {
  case "$1" in
    .gitattributes|.gitignore|.gitencrypt/*|.githooks/*) return 0 ;;
    *) return 1 ;;
  esac
}

if ! filter_configured; then
  echo "repo-crypt: filters not configured. Run: .gitencrypt/setup.sh" >&2
  exit 1
fi

# Ensure filter scripts are executable (clone does not always preserve +x).
chmod +x \
  "${SCRIPT_DIR}/clean.sh" \
  "${SCRIPT_DIR}/smudge.sh" \
  "${SCRIPT_DIR}/textconv.sh" \
  "${SCRIPT_DIR}/unlock.sh" \
  "${SCRIPT_DIR}/lock.sh" \
  "${SCRIPT_DIR}/verify_coverage.sh" \
  "${SCRIPT_DIR}/setup.sh" 2>/dev/null || true

clear_key
# Keep this unlock process as the key owner for the whole decrypt loop.
REPO_CRYPT_NO_WATCHDOG=1 prompt_and_store_key "unlock working tree"
# Re-stamp owner as this script ($$) so smudge children can use the key
# for the full duration of unlock, independent of the parent shell.
printf '%s' "$$" >"${OWNER_FILE}"

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  clear_key
  echo "repo-crypt: no commits yet" >&2
  exit 0
fi

echo "repo-crypt: decrypting working tree from git objects..." >&2

decrypted=0
failed=0
sample_ok=""

while IFS= read -r -d '' f; do
  if is_exempt "${f}"; then
    continue
  fi

  dir="$(dirname "${f}")"
  mkdir -p "${dir}"

  tmp="$(mktemp "${dir}/.repo-crypt-XXXXXX")"
  if ! git cat-file blob "HEAD:${f}" | "${SCRIPT_DIR}/smudge.sh" "${f}" >"${tmp}"; then
    rm -f "${tmp}"
    echo "repo-crypt: failed to decrypt: ${f}" >&2
    failed=1
    break
  fi
  mv "${tmp}" "${f}"
  decrypted=$((decrypted + 1))

  if [[ -z "${sample_ok}" && -f "${f}" ]]; then
    if [[ "$(head -c 10 "${f}")" == "${MAGIC}" ]]; then
      echo "repo-crypt: ${f} is still ciphertext — wrong key?" >&2
      failed=1
      break
    fi
    sample_ok="${f}"
  fi
done < <(git ls-files -z)

clear_key

if [[ "${failed}" -ne 0 ]]; then
  echo "repo-crypt: decrypt aborted after ${decrypted} file(s). Fix the key and re-run unlock." >&2
  exit 1
fi

if [[ "${decrypted}" -eq 0 ]]; then
  echo "repo-crypt: no encrypted files found to decrypt" >&2
  exit 1
fi

echo "repo-crypt: decrypted ${decrypted} file(s)" >&2
if [[ -n "${sample_ok}" ]]; then
  echo "repo-crypt: verified plaintext: ${sample_ok}" >&2
fi
echo "repo-crypt: key cleared (you will be prompted again on the next git command)" >&2
