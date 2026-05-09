#!/usr/bin/env bash
set -euo pipefail

# Record user UAT approval for the current HEAD. Writes the commit SHA to
# .uat_approved so the pre-push hook can verify approval matches what's
# being pushed. Must be run AFTER the QA command so timestamps order correctly.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SHA=$(git rev-parse HEAD)
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
    echo "$SHA"
    echo "$DATE"
} > .uat_approved

echo "Recorded UAT approval for commit: $SHA"
