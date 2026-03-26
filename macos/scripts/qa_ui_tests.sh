#!/usr/bin/env bash
# qa_ui_tests.sh
# Layer 3: XCUITest suite. Requires a real signed build and Accessibility permissions.
# Only runs on workflow_dispatch (not on every PR push) — see ui-qa.yml.
#
# Env vars:
#   CI=true                          — set by GitHub Actions
#   HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1  — required; guards against accidental local runs
#
# Used by: .github/workflows/ui-qa.yml (ui-tests job, workflow_dispatch only)
set -euo pipefail

if [ "${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}" != "1" ]; then
  echo "❌ Set HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 to run UI tests" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/../HomeTeam.xcodeproj"
DERIVED_DATA="/tmp/HomeTeamDerivedUITests"
RESULT_BUNDLE="/tmp/HomeTeamUIQA_$(date +%s).xcresult"

echo "▶ HomeTeam UI tests (Layer 3)"

xcodebuild test \
  -project "$PROJECT" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -only-testing HomeTeamUITests \
  -resultBundlePath "$RESULT_BUNDLE"

echo "✅ UI tests passed — $RESULT_BUNDLE"
