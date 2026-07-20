#!/usr/bin/env bash
# Configure this repo for full-tree symmetric encryption via git filters + hooks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "repo-crypt: initializing git repository..." >&2
  git init
fi

chmod +x \
  "${SCRIPT_DIR}/clean.sh" \
  "${SCRIPT_DIR}/smudge.sh" \
  "${SCRIPT_DIR}/textconv.sh" \
  "${SCRIPT_DIR}/unlock.sh" \
  "${SCRIPT_DIR}/lock.sh" \
  "${SCRIPT_DIR}/verify_coverage.sh" \
  "${SCRIPT_DIR}/setup.sh" \
  "${REPO_ROOT}/.githooks/pre-commit" \
  "${REPO_ROOT}/.githooks/post-checkout" \
  "${REPO_ROOT}/.githooks/post-merge" \
  "${REPO_ROOT}/.githooks/post-rewrite"

# Versioned hooks path so clone/pull share the same behavior.
git config core.hooksPath .githooks

# Clean/smudge: encrypt on add/commit, decrypt on checkout/pull.
# %f = path relative to repo root (needed for deterministic salt).
git config filter.repo-crypt.clean "${SCRIPT_DIR}/clean.sh %f"
git config filter.repo-crypt.smudge "${SCRIPT_DIR}/smudge.sh %f"
git config filter.repo-crypt.required true

# Show plaintext in diffs when key is available.
git config diff.repo-crypt.textconv "${SCRIPT_DIR}/textconv.sh"

echo "repo-crypt: git filters and hooks installed" >&2
echo "repo-crypt: next — enter your key (cached only under .git/, never committed)" >&2

"${SCRIPT_DIR}/unlock.sh" --force

echo "" >&2
echo "Done. Workflow:" >&2
echo "  • commit/add  → prompts for key if needed, encrypts every non-exempt file" >&2
echo "  • pull/checkout/merge → prompts for key if needed, decrypts into the working tree" >&2
echo "  • .gitencrypt/lock.sh   → forget the local key" >&2
echo "  • .gitencrypt/unlock.sh → re-enter the key and decrypt" >&2
