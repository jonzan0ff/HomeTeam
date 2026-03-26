#!/usr/bin/env bash
# persist_test_history.sh <source_dir> <history_branch>
# Appends telemetry files from <source_dir> to <history_branch> as a new commit.
# Creates the branch as an orphan if it doesn't exist yet.
# Safe to call with an empty source_dir (produces a no-op commit).
#
# Requires: git, write access to origin (workflow needs permissions: contents: write)
# Used by: .github/workflows/qa-regression-telemetry.yml
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: persist_test_history.sh <source_dir> <history_branch>" >&2
  exit 1
fi

SOURCE_DIR="$1"
HISTORY_BRANCH="$2"
RUN_ID="${GITHUB_RUN_ID:-local_$(date +%s)}"
COMMIT_MSG="${QA_HISTORY_COMMIT_MESSAGE:-"qa: telemetry run $RUN_ID"}"

echo "▶ Persisting telemetry to branch '$HISTORY_BRANCH'"

if [ ! -d "$SOURCE_DIR" ] || [ -z "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]; then
  echo "  ⚠️  source_dir '$SOURCE_DIR' is empty or missing — nothing to persist"
  exit 0
fi

# Configure git identity for CI if not already set
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "ci@hometeam.local"
  git config user.name "HomeTeam CI"
fi

# Stash any working-tree changes so we can safely switch branches
git stash --include-untracked --quiet 2>/dev/null || true

# Check if history branch exists on remote
BRANCH_EXISTS=false
git fetch origin "$HISTORY_BRANCH" 2>/dev/null && BRANCH_EXISTS=true || true

if [ "$BRANCH_EXISTS" = true ]; then
  git checkout "$HISTORY_BRANCH"
  git pull origin "$HISTORY_BRANCH" --ff-only
else
  echo "  Creating orphan branch '$HISTORY_BRANCH'"
  git checkout --orphan "$HISTORY_BRANCH"
  git rm -rf . --quiet 2>/dev/null || true
  echo "# HomeTeam QA Telemetry History" > README.md
  git add README.md
  git commit -m "qa: initialise history branch"
fi

# Copy telemetry files into a dated subdirectory
RUN_DIR="runs/$(date -u +%Y/%m/%d)/${RUN_ID}"
mkdir -p "$RUN_DIR"
cp -r "$SOURCE_DIR"/. "$RUN_DIR/"

git add "$RUN_DIR"
if git diff --cached --quiet; then
  echo "  No new telemetry files — skipping commit"
else
  git commit -m "$COMMIT_MSG"
  git push origin "$HISTORY_BRANCH"
  echo "✅ Telemetry committed to '$HISTORY_BRANCH' at $RUN_DIR"
fi

# Restore original branch
git checkout - 2>/dev/null || true
git stash pop --quiet 2>/dev/null || true
