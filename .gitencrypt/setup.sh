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
  "${REPO_ROOT}/.githooks/post-commit" \
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
echo "repo-crypt: you will be prompted for the key on every git add/commit/pull/checkout" >&2

echo "" >&2
echo "Done. Workflow:" >&2
echo "  • every git add/commit/pull/checkout → enter key once for that command" >&2
echo "  • key is wiped when the command finishes (not stored)" >&2
echo "  • .gitencrypt/unlock.sh → decrypt working tree, then forget the key" >&2
