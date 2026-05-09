#!/usr/bin/env bash
# build_verification_unit_gate.sh — compile gate on GitHub Actions
# Used by: .github/workflows/unit-gate.yml
#
# Scope: build only. Per qa-standards.md §8, all native Mac app tests
# (XCTest, XCUITest, snapshots) run on claudesandbox, not in GitHub CI.
# CI runners cannot run AppKit/SwiftUI tests reliably — `xcodebuild test`
# crashes with `CGSConnectionByID` assertion when the test bundle loads
# the app module which initializes AppKit, because GitHub runners lack a
# window server session for headless processes.
#
# This gate verifies the project compiles cleanly. Test execution happens
# on claudesandbox per qa-standards.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/../HomeTeam.xcodeproj"

echo "▶ HomeTeam unit gate (compile-only)"
echo "  project : $PROJECT"

xcodebuild build \
  -project "$PROJECT" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  ENABLE_TESTABILITY=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

echo "✅ Compile gate passed"
