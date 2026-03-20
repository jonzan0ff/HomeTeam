#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <current-telemetry-dir> [history-branch]" >&2
  exit 1
fi

CURRENT_DIR="$1"
HISTORY_BRANCH="${2:-qa-history}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hometeam-qa-history.XXXXXX")"

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  rm -rf "$WORKTREE_DIR"
}
trap cleanup EXIT

git -C "$REPO_ROOT" fetch origin "$HISTORY_BRANCH":"refs/remotes/origin/$HISTORY_BRANCH" || true

if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$HISTORY_BRANCH"; then
  git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" "refs/remotes/origin/$HISTORY_BRANCH"
else
  git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_DIR"
  git -C "$WORKTREE_DIR" checkout --orphan "$HISTORY_BRANCH"
  git -C "$WORKTREE_DIR" rm -rf . >/dev/null 2>&1 || true
fi

mkdir -p "$WORKTREE_DIR/qa/history"

"$REPO_ROOT/macos/scripts/append_test_history.sh" "$CURRENT_DIR" "$WORKTREE_DIR/qa/history"

POLICY_SOURCE="$REPO_ROOT/qa/test-retirement-policy.json"
POLICY_TARGET="$WORKTREE_DIR/qa/test-retirement-policy.json"

if [[ -f "$POLICY_SOURCE" ]]; then
  mkdir -p "$WORKTREE_DIR/qa"
  cp "$POLICY_SOURCE" "$POLICY_TARGET"
else
  echo "FAIL: Missing policy file at $POLICY_SOURCE" >&2
  exit 1
fi

python3 "$REPO_ROOT/macos/scripts/generate_regression_candidates.py" \
  --history "$WORKTREE_DIR/qa/history/test_cases.ndjson" \
  --policy "$POLICY_TARGET" \
  --markdown "$WORKTREE_DIR/qa/history/regression_candidates.md" \
  --json "$WORKTREE_DIR/qa/history/regression_candidates.json"

git -C "$WORKTREE_DIR" add qa/history qa/test-retirement-policy.json

if git -C "$WORKTREE_DIR" diff --cached --quiet; then
  echo "No history changes to commit."
  exit 0
fi

git -C "$WORKTREE_DIR" config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git -C "$WORKTREE_DIR" config user.email "${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}"

COMMIT_MESSAGE="${QA_HISTORY_COMMIT_MESSAGE:-qa: append telemetry run ${GITHUB_RUN_ID:-local}}"
git -C "$WORKTREE_DIR" commit -m "$COMMIT_MESSAGE"

if [[ "${HOMETEAM_QA_PERSIST_DRY_RUN:-0}" == "1" ]]; then
  echo "Dry run enabled. Commit created locally; skipping push."
  exit 0
fi

git -C "$WORKTREE_DIR" push origin "HEAD:$HISTORY_BRANCH"

echo "Telemetry history updated on branch: $HISTORY_BRANCH"
