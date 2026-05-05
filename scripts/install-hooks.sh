#!/usr/bin/env bash
set -euo pipefail

# Point git at the tracked hooks/ directory in this repo instead of the
# default untracked .git/hooks/. This makes hook enforcement part of the
# repository — it survives fresh clones and any local hook wipe.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

chmod +x hooks/* scripts/*.sh 2>/dev/null || true

git config core.hooksPath hooks

echo "Installed hooks from: $(git config core.hooksPath)"
