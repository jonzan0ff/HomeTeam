#!/usr/bin/env bash
set -euo pipefail

if [[ "${HOMETEAM_DESKTOP_AUTOMATION_OVERRIDE:-0}" != "1" && "${HOMETEAM_DESKTOP_AUTOMATION_QA:-0}" != "1" ]]; then
  echo "FAIL: Desktop automation is locked."
  echo "Use macos/scripts/qa_ui_tests.sh (sets HOMETEAM_DESKTOP_AUTOMATION_QA=1), or set HOMETEAM_DESKTOP_AUTOMATION_OVERRIDE=1 for ad-hoc commands."
  exit 2
fi

if [[ "$#" -lt 1 ]]; then
  echo "Usage: HOMETEAM_DESKTOP_AUTOMATION_OVERRIDE=1 $0 <command> [args...]"
  echo "Allowed commands: open, osascript, screencapture, xcodebuild (HomeTeamUITests only)"
  exit 2
fi

case "$1" in
  open|osascript|screencapture)
    ;;
  xcodebuild)
    joined_args=" $* "
    if [[ "$joined_args" != *" HomeTeamUITests "* ]] && [[ "$joined_args" != *" -only-testing:HomeTeamUITests/"* ]]; then
      echo "FAIL: xcodebuild desktop automation must target HomeTeamUITests."
      exit 2
    fi
    ;;
  *)
    echo "FAIL: '$1' is not permitted by desktop automation gate."
    echo "Allowed commands: open, osascript, screencapture, xcodebuild (HomeTeamUITests only)"
    exit 2
    ;;
esac

exec "$@"
