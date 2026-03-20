#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULT_BUNDLE="/tmp/HomeTeamUIQA_${TIMESTAMP}.xcresult"
ARTIFACT_ROOT="$ROOT_DIR/macos/artifacts/uiqa"
ATTACHMENTS_DIR="$ARTIFACT_ROOT/$TIMESTAMP"
ATTACHMENTS_EXPORT_DIR="$ATTACHMENTS_DIR/xcresult_attachments"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/HomeTeamDerived}"
ALLOW_LOCAL_XCODEBUILD="${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}"
RUN_NETWORK_TESTS="${HOMETEAM_RUN_NETWORK_TESTS:-1}"
SHARED_CONTAINER_ROOT="${HOMETEAM_SHARED_CONTAINER_DIR:-/tmp/HomeTeamSharedContainer}"
EXPECTED_SPORT_TOKENS=(nhl mlb nfl nba mls premierleague f1 motogp)
WIDGET_EDIT_REGRESSION_TESTS=(
  "HomeTeamTests/StreamingFilterTests/testWidgetTeamSelectionUsesConfiguredTeamWhenPresent"
  "HomeTeamTests/StreamingFilterTests/testWidgetTeamSelectionFallsBackToFavoriteBeforeRecent"
  "HomeTeamTests/StreamingFilterTests/testWidgetTeamSelectionUsesFavoriteWhenConfiguredIDIsUnknown"
  "HomeTeamTests/StreamingFilterTests/testWidgetConfigurationTeamsDoNotCollapseToRecentOnly"
  "HomeTeamTests/StreamingFilterTests/testWidgetConfigurationTeamsIncludeOnlyFavoritesInOrder"
  "HomeTeamTests/StreamingFilterTests/testRegressionNewWidgetTeamPickerMatchesPersistedFavoritesNotRecents"
  "HomeTeamTests/StreamingFilterTests/testWidgetShowsCatchUpMessageWhenGamesExistButNoPreviousOrUpcomingRows"
  "HomeTeamTests/StreamingFilterTests/testWidgetGlobalEmptyExplainsStreamingFiltersWhenUpcomingWouldBeHidden"
  "HomeTeamTests/StreamingFilterTests/testWidgetPreviousRowStillShowsWhenUpcomingFilteredByStreaming"
  "HomeTeamTests/StreamingFilterTests/testPrioritizedWidgetConfigurationTeamsUsesFavoriteThenRecentOrder"
  "HomeTeamTests/StreamingFilterTests/testWidgetUnconfiguredStateWithFavoritesShowsEditGuidance"
  "HomeTeamTests/StreamingFilterTests/testWidgetUnconfiguredStateWithoutFavoritesPromptsToAddFavorites"
  "HomeTeamTests/StreamingFilterTests/testWidgetConfiguredStateUsesSnapshotErrorForEmptyStateDetail"
)

SNAPSHOT_MODE="${HOMETEAM_QA_WIDGET_SNAPSHOT_MODE:-prod}"
QA_STORAGE_MODE="${HOMETEAM_QA_STORAGE_MODE:-prod}"
ENFORCE_WIDGET_EDIT_REGRESSION="${HOMETEAM_QA_ENFORCE_WIDGET_EDIT_REGRESSION:-1}"

if [[ "$SNAPSHOT_MODE" != "coverage" && "$SNAPSHOT_MODE" != "prod" ]]; then
  echo "FAIL: HOMETEAM_QA_WIDGET_SNAPSHOT_MODE must be 'coverage' or 'prod'."
  exit 2
fi

if [[ "$QA_STORAGE_MODE" != "isolated" && "$QA_STORAGE_MODE" != "prod" ]]; then
  echo "FAIL: HOMETEAM_QA_STORAGE_MODE must be 'isolated' or 'prod'."
  exit 2
fi

if [[ "$ENFORCE_WIDGET_EDIT_REGRESSION" != "1" && "$ENFORCE_WIDGET_EDIT_REGRESSION" != "0" ]]; then
  echo "FAIL: HOMETEAM_QA_ENFORCE_WIDGET_EDIT_REGRESSION must be '1' or '0'."
  exit 2
fi

if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && "$ALLOW_LOCAL_XCODEBUILD" != "1" ]]; then
  echo "FAIL: Local xcodebuild QA is disabled to avoid macOS privacy prompts."
  echo "Run this in CI, or set HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 for local developer-only runs."
  exit 2
fi

if [[ "$RUN_NETWORK_TESTS" != "1" ]]; then
  echo "FAIL: UI widget snapshot QA requires live network data. Set HOMETEAM_RUN_NETWORK_TESTS=1."
  exit 2
fi

mkdir -p "$ATTACHMENTS_DIR" "$ATTACHMENTS_EXPORT_DIR"
if [[ "$QA_STORAGE_MODE" == "isolated" ]]; then
  mkdir -p "$SHARED_CONTAINER_ROOT"
fi

echo "Mode: prompt-free in-process snapshot QA."
echo "Snapshot mode: $SNAPSHOT_MODE"
echo "Storage mode: $QA_STORAGE_MODE"
echo "Widget edit regressions: $ENFORCE_WIDGET_EDIT_REGRESSION"

RUN_ENV=(
  "HOMETEAM_WIDGET_ARTIFACT_DIR=$ATTACHMENTS_DIR"
  "HOMETEAM_RUN_NETWORK_TESTS=$RUN_NETWORK_TESTS"
  "HOMETEAM_QA_WIDGET_SNAPSHOT_MODE=$SNAPSHOT_MODE"
  "TZ=UTC"
  "LANG=en_US_POSIX"
)
if [[ "$QA_STORAGE_MODE" == "isolated" ]]; then
  RUN_ENV+=("HOMETEAM_SHARED_CONTAINER_DIR=$SHARED_CONTAINER_ROOT")
fi

XCODEBUILD_TEST_ARGS=(
  "-only-testing:HomeTeamTests/WidgetSnapshotArtifactTests"
)
if [[ "$ENFORCE_WIDGET_EDIT_REGRESSION" == "1" ]]; then
  for test_name in "${WIDGET_EDIT_REGRESSION_TESTS[@]}"; do
    XCODEBUILD_TEST_ARGS+=("-only-testing:$test_name")
  done
fi

env "${RUN_ENV[@]}" xcodebuild \
  -project macos/HomeTeam.xcodeproj \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  test \
  "${XCODEBUILD_TEST_ARGS[@]}"

xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$ATTACHMENTS_EXPORT_DIR"

XCRESULT_MANIFEST_PATH="$ATTACHMENTS_EXPORT_DIR/manifest.json"
if [[ ! -f "$XCRESULT_MANIFEST_PATH" ]]; then
  echo "FAIL: xcresult attachment manifest missing at $XCRESULT_MANIFEST_PATH."
  exit 1
fi

if [[ "$SNAPSHOT_MODE" == "coverage" ]]; then
  for sport_token in "${EXPECTED_SPORT_TOKENS[@]}"; do
    if ! jq -e --arg prefix "widget-${sport_token}-large_" '
      [.[].attachments[]?.suggestedHumanReadableName] as $names
      | any($names[]; startswith($prefix))
    ' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
      echo "FAIL: Missing live widget snapshot attachment for sport lane: $sport_token"
      echo "Manifest: $XCRESULT_MANIFEST_PATH"
      exit 1
    fi
  done
else
  if ! jq -e '
    [.[].attachments[]?.suggestedHumanReadableName] as $names
    | any($names[]; startswith("widget-prod-"))
  ' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
    echo "FAIL: Missing prod-parity widget snapshot attachment(s)."
    echo "Manifest: $XCRESULT_MANIFEST_PATH"
    exit 1
  fi
fi

if ! jq -e '
  [.[].attachments[]?.exportedFileName] | length >= 2
' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
  echo "FAIL: Expected at least two exported snapshot attachments."
  exit 1
fi

echo
echo "UI QA artifacts:"
echo "  Mode:          prompt-free-snapshot"
echo "  Result bundle: $RESULT_BUNDLE"
echo "  Attachments:   $ATTACHMENTS_DIR"
echo "  xcresult dump: $ATTACHMENTS_EXPORT_DIR"
echo
find "$ATTACHMENTS_DIR" -type f -name '*.png' | sort
