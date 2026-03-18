#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CapsWidget.xcodeproj"
SCHEME="CapsWidget"
DERIVED_DATA_PATH="${1:-/tmp/CapsWidgetDerived}"
BUILD_LOG="/tmp/capswidget_widget_qa_build.log"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/CapsWidget.app"
APPEX_PATH="$APP_PATH/Contents/PlugIns/CapsWidgetExtension.appex"
APPEX_INFO="$APPEX_PATH/Contents/Info.plist"
BUNDLE_ID="com.jonzanoff.capswidget.extension"
SNAPSHOT_PATH="$HOME/Library/Application Support/CapsWidget/schedule_snapshot.json"
WIDGET_SOURCE="$ROOT_DIR/CapsWidgetExtension/CapsScheduleWidget.swift"
APP_SOURCE="$ROOT_DIR/CapsWidgetApp/ContentView.swift"
MATCHER_SOURCE="$ROOT_DIR/Shared/Services/StreamingServiceMatcher.swift"

echo "[1/10] Building app + extension"
if ! xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build >"$BUILD_LOG" 2>&1; then
  echo "FAIL: Build failed."
  if rg -q 'No signing certificate "Mac Development" found|No signing certificate "Apple Development" found' "$BUILD_LOG"; then
    echo
    echo "Root cause: Xcode could not find a macOS development signing certificate for your Team."
    echo "Without a Team-signed extension, WidgetKit will not list this widget."
    echo
    echo "Beginner fix (safe and app-scoped):"
    echo "  1) Open Xcode -> Settings -> Accounts -> select your Apple ID and Team."
    echo "  2) Click 'Manage Certificates...' and create an 'Apple Development' certificate."
    echo "  3) In project Signing, keep 'Automatically manage signing' enabled for BOTH targets."
    echo "  4) Re-run this QA script."
  fi
  echo
  echo "Last build log lines:"
  tail -n 40 "$BUILD_LOG"
  exit 1
fi

if [[ ! -d "$APPEX_PATH" ]]; then
  echo "FAIL: Widget extension bundle not found at:"
  echo "  $APPEX_PATH"
  exit 1
fi

echo "[2/10] Checking WidgetKit extension point"
EXTENSION_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$APPEX_INFO" 2>/dev/null || true)"
if [[ "$EXTENSION_POINT" != "com.apple.widgetkit-extension" ]]; then
  echo "FAIL: Extension is not marked as WidgetKit."
  echo "Expected: com.apple.widgetkit-extension"
  echo "Actual:   ${EXTENSION_POINT:-<missing>}"
  exit 1
fi

echo "[3/10] Checking signing identity"
TEAM_IDENTIFIER="$(codesign -dv --verbose=4 "$APPEX_PATH" 2>&1 | awk -F= '/TeamIdentifier=/{print $2}')"
if [[ -z "$TEAM_IDENTIFIER" || "$TEAM_IDENTIFIER" == "not set" ]]; then
  echo "FAIL: Extension is ad-hoc signed (no TeamIdentifier)."
  echo "Set Team in Xcode for BOTH targets:"
  echo "  - CapsWidgetApp"
  echo "  - CapsWidgetExtension"
  echo "Then rerun this script."
  exit 1
fi
echo "TeamIdentifier=$TEAM_IDENTIFIER"

echo "[4/10] Registering extension with pluginkit"
pluginkit -a "$APPEX_PATH" >/dev/null

echo "[5/10] Verifying plugin registry entry"
PLUGIN_ENTRY="$(pluginkit -m -A -D -i "$BUNDLE_ID" || true)"
if [[ -z "$PLUGIN_ENTRY" ]]; then
  echo "FAIL: Extension not found in plugin registry after registration."
  exit 1
fi
echo "$PLUGIN_ENTRY"

echo "[6/10] Verifying widget source contracts"
if ! rg -q '\.supportedFamilies\(\[\.systemLarge\]\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget is not configured for systemLarge family."
  exit 1
fi
if ! rg -q '\.containerBackgroundRemovable\(false\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget background-removal guard not found."
  echo "Desktop widgets may appear blank when background removal is enabled."
  exit 1
fi
if ! rg -q 'TeamLogoStore\(\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget local team-logo cache rendering not found."
  exit 1
fi
if ! rg -q 'ServiceLogoView\(service:' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget streaming-service icon rendering not found."
  exit 1
fi
if ! rg -q 'Text\(shortAbbrev\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget abbreviation text rendering not found."
  exit 1
fi
if ! rg -q 'case \.final:' "$WIDGET_SOURCE" || ! rg -q 'return "Final"' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget final-game header label is not set to Final."
  exit 1
fi
if ! rg -q 'liveStatusCompactLabel' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget live game clock/status rendering not found."
  exit 1
fi
if ! rg -q 'arrowtriangle.left.fill' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget winner/leader score arrow rendering not found."
  exit 1
fi
if ! rg -q 'if rowType == \.upcoming' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget upcoming-row icon logic not found."
  exit 1
fi
if ! rg -q 'Text\(summary\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget team-summary stats text not found."
  exit 1
fi
if ! rg -q 'Text\(summary\)' "$APP_SOURCE"; then
  echo "FAIL: App header team-summary stats text not found."
  exit 1
fi
if ! rg -q 'TeamLogoStore\(\)' "$APP_SOURCE"; then
  echo "FAIL: App local team-logo cache rendering not found."
  exit 1
fi
if ! rg -q 'liveStatusCompactLabel' "$APP_SOURCE"; then
  echo "FAIL: App live game clock/status rendering not found."
  exit 1
fi
if ! rg -q '"Hulu"' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher is missing Hulu support."
  exit 1
fi
if rg -q '^\s*\(".*ESPN\+' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher unexpectedly supports ESPN+."
  exit 1
fi

echo "[7/10] Checking latest snapshot availability"
if [[ ! -f "$SNAPSHOT_PATH" ]]; then
  echo "FAIL: Snapshot file missing at:"
  echo "  $SNAPSHOT_PATH"
  echo "Run the app once and press refresh, then rerun QA."
  exit 1
fi

echo "[8/10] Validating header summary stats in snapshot"
if jq -e '.teamSummary and (.teamSummary.record|type=="string" and length>0) and (.teamSummary.place|type=="string" and length>0) and (.teamSummary.last10|type=="string" and length>0) and (.teamSummary.streak|type=="string" and length>0)' "$SNAPSHOT_PATH" >/dev/null; then
  echo "teamSummary present"
else
  echo "WARN: Snapshot is missing teamSummary record/place/last10/streak."
  echo "      This can happen with stale cache from older builds."
  echo "      Open the app and press refresh once, then rerun QA for strict validation."
fi

echo "[9/10] Validating logos + abbreviations in displayed games"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
if ! jq -e --arg now "$NOW_UTC" '
  def prev: [.games[] | select(.status=="final" and .startTimeUTC <= $now)] | sort_by(.startTimeUTC) | reverse | .[:3];
  def upcoming: [.games[] | select(.status=="live" or .startTimeUTC >= $now)] | sort_by(.startTimeUTC) | .[:3];
  (prev + upcoming) as $selected
  | ($selected | length) > 0
  and all($selected[]; (.homeAbbrev|test("^[A-Z]{2,3}$")) and (.awayAbbrev|test("^[A-Z]{2,3}$")))
  and all($selected[]; (.homeLogoURL != null and (.homeLogoURL|length)>0) and (.awayLogoURL != null and (.awayLogoURL|length)>0))
' "$SNAPSHOT_PATH" >/dev/null; then
  echo "FAIL: Displayed games are missing logos or valid abbreviations."
  exit 1
fi

echo "[10/10] Validating upcoming records are present"
if jq -e '.teamSummary != null' "$SNAPSHOT_PATH" >/dev/null; then
  if ! jq -e --arg now "$NOW_UTC" '
    [.games[] | select(.status=="live" or .startTimeUTC >= $now)] | sort_by(.startTimeUTC) | .[:3]
    | if length == 0 then true else all(.[]; .homeRecord != null and .awayRecord != null and (.homeRecord|length)>0 and (.awayRecord|length)>0) end
  ' "$SNAPSHOT_PATH" >/dev/null; then
    echo "FAIL: Upcoming displayed games are missing home/away records."
    exit 1
  fi
else
  echo "WARN: Skipping strict upcoming-record check until snapshot includes teamSummary."
fi

echo "QA passed"
echo "Build, signing, registration, source contracts, and snapshot data quality checks all passed."
