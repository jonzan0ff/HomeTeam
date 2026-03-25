#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/HomeTeam.xcodeproj"
SCHEME="HomeTeam"
DERIVED_DATA_PATH="${1:-/tmp/HomeTeamDerived}"
BUILD_LOG="/tmp/hometeam_widget_qa_build.log"
TEST_LOG="/tmp/hometeam_widget_qa_test.log"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/HomeTeam.app"
APPEX_PATH="$APP_PATH/Contents/PlugIns/HomeTeamWidgetExtension.appex"
APPEX_INFO="$APPEX_PATH/Contents/Info.plist"
BUNDLE_ID="com.jonzanoff.hometeam.widget"
APP_GROUP_ID="group.com.jonzanoff.hometeam"
SHARED_CONTAINER_ROOT="${HOMETEAM_SHARED_CONTAINER_DIR:-$HOME/Library/Group Containers/$APP_GROUP_ID}"
TARGET_COMPOSITE_ID="${HOMETEAM_QA_TEAM_COMPOSITE_ID:-f1:5789}"
TARGET_SNAPSHOT_ID="$(echo "$TARGET_COMPOSITE_ID" | tr '[:upper:]' '[:lower:]' | tr ':/' '__')"
GROUP_ROOT="$SHARED_CONTAINER_ROOT/HomeTeam"
GROUP_SNAPSHOT_PATH="$GROUP_ROOT/schedule_snapshot_${TARGET_SNAPSHOT_ID}.json"
GROUP_LOGO_CACHE_DIR="$GROUP_ROOT/team_logos"
WIDGET_SOURCE="$ROOT_DIR/HomeTeamExtension/HomeTeamWidget.swift"
WIDGET_CONTENT_SOURCE="$ROOT_DIR/Shared/Models/HomeTeamGame+Presentation.swift"
APP_SOURCE="$ROOT_DIR/HomeTeamApp/ContentView.swift"
MATCHER_SOURCE="$ROOT_DIR/Shared/Services/StreamingServiceMatcher.swift"
PRESENTATION_SOURCE="$ROOT_DIR/Shared/Models/HomeTeamGame+Presentation.swift"

RUN_NETWORK_TESTS="${HOMETEAM_RUN_NETWORK_TESTS:-1}"
ALLOW_WIDGET_REGISTRY_WARN="${HOMETEAM_QA_ALLOW_WIDGET_REGISTRY_WARN:-0}"
REQUIRE_WIDGET_SCREENSHOT="${HOMETEAM_QA_REQUIRE_WIDGET_SCREENSHOT:-1}"
ALLOW_LOCAL_XCODEBUILD="${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}"

if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && "$ALLOW_LOCAL_XCODEBUILD" != "1" ]]; then
  echo "FAIL: Local xcodebuild QA is disabled to avoid macOS privacy prompts."
  echo "Run this in CI, or set HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 for local developer-only runs."
  exit 2
fi

mkdir -p "$SHARED_CONTAINER_ROOT"
export HOMETEAM_SHARED_CONTAINER_DIR="$SHARED_CONTAINER_ROOT"

echo "[1/12] Building app + extension"
if ! xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
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

echo "[2/12] Running automated regression tests (prompt-free unit/integration lane)"
if ! HOMETEAM_SHARED_CONTAINER_DIR="$SHARED_CONTAINER_ROOT" HOMETEAM_RUN_NETWORK_TESTS="$RUN_NETWORK_TESTS" xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test \
  -only-testing:HomeTeamTests >"$TEST_LOG" 2>&1; then
  echo "FAIL: Automated tests failed."
  echo
  echo "Last test log lines:"
  tail -n 60 "$TEST_LOG"
  exit 1
fi

echo "[3/12] Checking WidgetKit extension point"
EXTENSION_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$APPEX_INFO" 2>/dev/null || true)"
if [[ "$EXTENSION_POINT" != "com.apple.widgetkit-extension" ]]; then
  echo "FAIL: Extension is not marked as WidgetKit."
  echo "Expected: com.apple.widgetkit-extension"
  echo "Actual:   ${EXTENSION_POINT:-<missing>}"
  exit 1
fi

echo "[4/12] Checking signing identity"
TEAM_IDENTIFIER="$(codesign -dv --verbose=4 "$APPEX_PATH" 2>&1 | awk -F= '/TeamIdentifier=/{print $2}')"
if [[ -z "$TEAM_IDENTIFIER" || "$TEAM_IDENTIFIER" == "not set" ]]; then
  echo "FAIL: Extension is ad-hoc signed (no TeamIdentifier)."
  echo "Set Team in Xcode for BOTH targets:"
  echo "  - HomeTeamApp"
  echo "  - HomeTeamWidgetExtension"
  echo "Then rerun this script."
  exit 1
fi
echo "TeamIdentifier=$TEAM_IDENTIFIER"

echo "[4b/12] Checking App Group entitlements"
APP_ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)"
APPEX_ENTITLEMENTS="$(codesign -d --entitlements :- "$APPEX_PATH" 2>/dev/null || true)"

if ! grep -q 'com.apple.security.application-groups' <<<"$APP_ENTITLEMENTS" || ! grep -q "$APP_GROUP_ID" <<<"$APP_ENTITLEMENTS"; then
  echo "FAIL: HomeTeamApp is missing App Group entitlement for $APP_GROUP_ID."
  exit 1
fi

if ! grep -q 'com.apple.security.application-groups' <<<"$APPEX_ENTITLEMENTS" || ! grep -q "$APP_GROUP_ID" <<<"$APPEX_ENTITLEMENTS"; then
  echo "FAIL: HomeTeamWidgetExtension is missing App Group entitlement for $APP_GROUP_ID."
  exit 1
fi

echo "[5/12] Registering extension with pluginkit"
pluginkit -a "$APP_PATH" >/dev/null || true
pluginkit -a "$APPEX_PATH" >/dev/null

echo "[6/12] Verifying plugin registry entry"
PLUGIN_ENTRY="$(pluginkit -m -A -D -i "$BUNDLE_ID" || true)"
if [[ -z "$PLUGIN_ENTRY" ]]; then
  if [[ "$ALLOW_WIDGET_REGISTRY_WARN" == "1" ]]; then
    echo "WARN: Extension not found in plugin registry after registration."
    echo "      Launch HomeTeam once to complete widget registration, then rerun QA."
  else
    echo "FAIL: Extension not found in plugin registry after registration."
    echo "      Launch HomeTeam once to complete widget registration, then rerun QA."
    echo "      To temporarily downgrade this to warning, run with HOMETEAM_QA_ALLOW_WIDGET_REGISTRY_WARN=1."
    exit 1
  fi
else
  echo "$PLUGIN_ENTRY"
fi

echo "[7/12] Verifying source contracts"
if ! rg -q '\.supportedFamilies\(' "$WIDGET_SOURCE" || ! rg -q '\.systemLarge' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget is not configured with systemLarge support."
  exit 1
fi
if rg -q '\.systemSmall|\.systemMedium' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget must be large-only; systemSmall/systemMedium support is still present."
  exit 1
fi
if ! rg -q '\.containerBackgroundRemovable\(false\)' "$WIDGET_SOURCE"; then
  echo "FAIL: Widget background-removal guard not found."
  exit 1
fi
if ! rg -q 'TeamLogoStore\(\)' "$WIDGET_CONTENT_SOURCE"; then
  echo "FAIL: Widget local team-logo cache rendering not found in shared widget content."
  exit 1
fi
if ! rg -q 'TeamLogoStore\(\)' "$APP_SOURCE"; then
  echo "FAIL: App local team-logo cache rendering not found."
  exit 1
fi
if rg -q 'AsyncImage\(' "$APP_SOURCE" || rg -q 'AsyncImage\(' "$WIDGET_CONTENT_SOURCE"; then
  echo "FAIL: App/widget logo rendering must use identical cache-first policy (no app-only AsyncImage fallback)."
  exit 1
fi
if ! rg -q 'ServiceLogoView\(service:' "$WIDGET_CONTENT_SOURCE"; then
  echo "FAIL: Widget streaming-service icon rendering not found in shared widget content."
  exit 1
fi
if ! rg -q 'showsRacingUpcomingEventName' "$WIDGET_CONTENT_SOURCE"; then
  echo "FAIL: Widget racing upcoming event-name display logic not found in shared widget content."
  exit 1
fi
if ! rg -q 'showsRacingUpcomingEventName' "$APP_SOURCE"; then
  echo "FAIL: App racing upcoming event-name display logic not found."
  exit 1
fi
if ! rg -q 'passesStreamingFilter' "$PRESENTATION_SOURCE"; then
  echo "FAIL: Streaming filter helper not found in game presentation model."
  exit 1
fi
if ! rg -q 'guard !matchedServices.isEmpty else' "$PRESENTATION_SOURCE" || ! rg -q 'return false' "$PRESENTATION_SOURCE"; then
  echo "FAIL: Strict streaming filter guard is missing."
  exit 1
fi
if ! rg -q '"Hulu"' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher is missing Hulu support."
  exit 1
fi
if ! rg -q '"Hulu TV"' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher is missing Hulu TV support."
  exit 1
fi
if ! rg -F -q '"ESPN+"' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher is missing ESPN+ support."
  exit 1
fi
if ! rg -q '"Apple TV"' "$MATCHER_SOURCE"; then
  echo "FAIL: Streaming matcher is missing Apple TV support."
  exit 1
fi

echo "[8/12] Checking latest snapshot availability for $TARGET_COMPOSITE_ID"
SNAPSHOT_PATH=""
if [[ -f "$GROUP_SNAPSHOT_PATH" ]]; then
  SNAPSHOT_PATH="$GROUP_SNAPSHOT_PATH"
fi

if [[ -z "$SNAPSHOT_PATH" ]]; then
  echo "FAIL: Snapshot file missing in App Group container. Checked:"
  echo "  $GROUP_SNAPSHOT_PATH"
  echo "Run the app once and press refresh so data migrates into the shared container, then rerun QA."
  exit 1
fi

echo "Using snapshot: $SNAPSHOT_PATH"

echo "[9/12] Validating team summary stats in snapshot"
if jq -e '.teamSummary and (.teamSummary.record|type=="string" and length>0) and (.teamSummary.place|type=="string" and length>0) and (.teamSummary.last10|type=="string" and length>0) and (.teamSummary.streak|type=="string" and length>0)' "$SNAPSHOT_PATH" >/dev/null; then
  echo "teamSummary present"
else
  echo "WARN: Snapshot is missing teamSummary record/place/last10/streak."
fi

echo "[10/12] Validating logos + abbreviations in displayed games"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
if ! jq -e --arg now "$NOW_UTC" '
  def prev: [.games[] | select(.status=="final" and .startTimeUTC <= $now)] | sort_by(.startTimeUTC) | reverse | .[:3];
  def upcoming: [.games[] | select(.status=="live" or .startTimeUTC >= $now)] | sort_by(.startTimeUTC) | .[:3];
  (prev + upcoming) as $selected
  | ($selected | length) > 0
  and all($selected[]; (.homeAbbrev|type=="string") and (.awayAbbrev|type=="string"))
  and all(
    $selected[];
    if ((.sport == "f1" or .sport == "motogp") and ((.racingResults // []) | length > 0)) then
      all((.racingResults // [])[]; (.teamAbbrev|type=="string" and length>0) and (.teamLogoURL|type=="string" and length>0))
    else
      true
    end
  )
' "$SNAPSHOT_PATH" >/dev/null; then
  echo "FAIL: Displayed games are missing expected abbreviation or racing-logo fields."
  exit 1
fi

echo "[10b/12] Validating racing logo cache files exist in shared container"
RACING_LOGO_URLS="$(jq -r --arg now "$NOW_UTC" '
  def prev: [.games[] | select(.status=="final" and .startTimeUTC <= $now)] | sort_by(.startTimeUTC) | reverse | .[:3];
  def upcoming: [.games[] | select(.status=="live" or .startTimeUTC >= $now)] | sort_by(.startTimeUTC) | .[:3];
  (prev + upcoming)
  | map(select((.sport == "f1" or .sport == "motogp") and ((.racingResults // []) | length > 0)))
  | [.[] | .racingResults[]? | .teamLogoURL | select(type=="string" and length>0)]
  | unique[]
' "$SNAPSHOT_PATH")"

if [[ -n "$RACING_LOGO_URLS" ]]; then
  if [[ ! -d "$GROUP_LOGO_CACHE_DIR" ]]; then
    echo "FAIL: Shared logo cache directory missing at:"
    echo "  $GROUP_LOGO_CACHE_DIR"
    exit 1
  fi

  alt_logo_url() {
    local logo_url="$1"
    if [[ "$logo_url" =~ ^https://logo\.clearbit\.com/([^/?#]+) ]]; then
      local domain="${BASH_REMATCH[1]}"
      echo "https://www.google.com/s2/favicons?domain=${domain}&sz=64"
      return 0
    fi

    if [[ "$logo_url" =~ ^https://www\.google\.com/s2/favicons\? ]]; then
      local domain=""
      domain="$(printf "%s" "$logo_url" | sed -n 's/.*[?&]domain=\([^&]*\).*/\1/p')"
      if [[ -n "$domain" ]]; then
        echo "https://logo.clearbit.com/${domain}"
        return 0
      fi
    fi

    return 1
  }

  missing_cached_logo=0
  while IFS= read -r logo_url; do
    [[ -z "$logo_url" ]] && continue
    logo_hash="$(printf "%s" "$logo_url" | shasum -a 256 | awk '{print $1}')"
    alt_url="$(alt_logo_url "$logo_url" || true)"
    alt_hash=""
    if [[ -n "$alt_url" ]]; then
      alt_hash="$(printf "%s" "$alt_url" | shasum -a 256 | awk '{print $1}')"
    fi

    if [[ ! -f "$GROUP_LOGO_CACHE_DIR/$logo_hash.img" && ( -z "$alt_hash" || ! -f "$GROUP_LOGO_CACHE_DIR/$alt_hash.img" ) ]]; then
      echo "FAIL: Missing cached racing logo in shared App Group:"
      echo "  url=$logo_url"
      echo "  expected_file=$GROUP_LOGO_CACHE_DIR/$logo_hash.img"
      if [[ -n "$alt_hash" ]]; then
        echo "  alternate_file=$GROUP_LOGO_CACHE_DIR/$alt_hash.img"
      fi
      missing_cached_logo=1
    fi
  done <<< "$RACING_LOGO_URLS"

  if [[ "$missing_cached_logo" -ne 0 ]]; then
    exit 1
  fi
else
  echo "WARN: No racing logo URLs found in selected displayed games."
fi

echo "[11/12] Validating upcoming records are present when available"
if jq -e '.teamSummary != null' "$SNAPSHOT_PATH" >/dev/null; then
  if ! jq -e --arg now "$NOW_UTC" '
    [.games[] | select(.status=="live" or .startTimeUTC >= $now)] | sort_by(.startTimeUTC) | .[:3]
    | if length == 0 then true else all(.[]; (.homeRecord != null and .awayRecord != null) or (.sport == "f1" or .sport == "motogp")) end
  ' "$SNAPSHOT_PATH" >/dev/null; then
    echo "FAIL: Upcoming displayed games are missing records for standard team sports."
    exit 1
  fi
else
  echo "WARN: Skipping strict upcoming-record check until snapshot includes teamSummary."
fi

echo "QA passed"
echo "Build, tests, registration, source contracts, and snapshot validations all passed."

echo "[12/12] Generating widget snapshot artifacts"
WIDGET_SCREENSHOT_SCRIPT="$ROOT_DIR/scripts/capture_widget_screenshot.sh"
if [[ -x "$WIDGET_SCREENSHOT_SCRIPT" ]]; then
  if ! "$WIDGET_SCREENSHOT_SCRIPT" "$ROOT_DIR/artifacts/widgetqa"; then
    if [[ "$REQUIRE_WIDGET_SCREENSHOT" == "1" ]]; then
      echo "FAIL: Widget snapshot generation failed."
      exit 1
    fi
    echo "WARN: Widget snapshot generation failed."
  fi
else
  if [[ "$REQUIRE_WIDGET_SCREENSHOT" == "1" ]]; then
    echo "FAIL: Missing widget snapshot script at $WIDGET_SCREENSHOT_SCRIPT."
    exit 1
  fi
  echo "WARN: Missing widget snapshot script at $WIDGET_SCREENSHOT_SCRIPT."
fi
