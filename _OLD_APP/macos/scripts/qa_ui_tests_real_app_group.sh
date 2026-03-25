#!/usr/bin/env bash
# Runs HomeTeamSharedContainerUITests with HOMETEAM_UI_TEST_REAL_APP_GROUP=1 (same App Group JSON as the widget).
# Optional: HOMETEAM_UI_TEST_DESTRUCTIVE_RESET=1 runs the reset + onboarding flow (wipes shared favorites).
# Requires signing + HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 (or CI=true).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

export HOMETEAM_UI_TEST_REAL_APP_GROUP=1

echo "[qa_ui_tests_real_app_group] DESTRUCTIVE_RESET=${HOMETEAM_UI_TEST_DESTRUCTIVE_RESET:-0}"

ONLY_TESTING="${HOMETEAM_UI_TESTS_ONLY:-HomeTeamUITests/HomeTeamSharedContainerUITests}"
export HOMETEAM_UI_TESTS_ONLY="$ONLY_TESTING"

exec "$ROOT_DIR/macos/scripts/qa_ui_tests.sh"
