#!/usr/bin/env bash
# Verify every staged path is covered by the repo-crypt filter (nothing missed).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

EXEMPT_REGEX='^(\.gitattributes|\.gitignore|\.gitencrypt/|\.githooks/)'

missing=0
while IFS= read -r -d '' path; do
  if [[ "${path}" =~ ${EXEMPT_REGEX} ]]; then
    continue
  fi
  # Ask git whether the crypt filter applies to this path.
  attr="$(git check-attr filter -- "${path}" | awk -F': ' '{print $3}')"
  if [[ "${attr}" != "repo-crypt" ]]; then
    echo "repo-crypt: NOT ENCRYPTED (missing filter): ${path}" >&2
    missing=1
  fi
done < <(git diff --cached --name-only -z --diff-filter=ACMR)

if [[ "${missing}" -ne 0 ]]; then
  echo "repo-crypt: refusing commit — some staged files would be stored in plaintext." >&2
  echo "Fix .gitattributes so '*' uses filter=repo-crypt, or move tooling under exempt paths." >&2
  exit 1
fi
