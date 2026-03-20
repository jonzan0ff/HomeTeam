#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACT_ROOT="${1:-$ROOT_DIR/artifacts/widgetqa}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/HomeTeamDerived}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$ARTIFACT_ROOT/$TIMESTAMP"
ATTACHMENT_EXPORT_DIR="$OUT_DIR/xcresult_attachments"
RESULT_BUNDLE="/tmp/HomeTeamWidgetSnapshot_${TIMESTAMP}.xcresult"
LOG_PATH="/tmp/hometeam_widget_snapshot_${TIMESTAMP}.log"
ALLOW_LOCAL_XCODEBUILD="${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}"
RUN_NETWORK_TESTS="${HOMETEAM_RUN_NETWORK_TESTS:-1}"
SHARED_CONTAINER_ROOT="${HOMETEAM_SHARED_CONTAINER_DIR:-/tmp/HomeTeamSharedContainer}"
EXPECTED_SPORT_TOKENS=(nhl mlb nfl nba mls premierleague f1 motogp)

SNAPSHOT_MODE="${HOMETEAM_QA_WIDGET_SNAPSHOT_MODE:-prod}"
QA_STORAGE_MODE="${HOMETEAM_QA_STORAGE_MODE:-prod}"

if [[ "$SNAPSHOT_MODE" != "coverage" && "$SNAPSHOT_MODE" != "prod" ]]; then
  echo "FAIL: HOMETEAM_QA_WIDGET_SNAPSHOT_MODE must be 'coverage' or 'prod'." >&2
  exit 2
fi

if [[ "$QA_STORAGE_MODE" != "isolated" && "$QA_STORAGE_MODE" != "prod" ]]; then
  echo "FAIL: HOMETEAM_QA_STORAGE_MODE must be 'isolated' or 'prod'." >&2
  exit 2
fi

if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && "$ALLOW_LOCAL_XCODEBUILD" != "1" ]]; then
  echo "FAIL: Local xcodebuild QA is disabled to avoid macOS privacy prompts." >&2
  echo "Run this in CI, or set HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 for local developer-only runs." >&2
  exit 2
fi

if [[ "$RUN_NETWORK_TESTS" != "1" ]]; then
  echo "FAIL: Widget snapshot QA requires live network data. Set HOMETEAM_RUN_NETWORK_TESTS=1." >&2
  exit 2
fi

mkdir -p "$OUT_DIR" "$ATTACHMENT_EXPORT_DIR"
if [[ "$QA_STORAGE_MODE" == "isolated" ]]; then
  mkdir -p "$SHARED_CONTAINER_ROOT"
fi

RUN_ENV=(
  "HOMETEAM_WIDGET_ARTIFACT_DIR=$OUT_DIR"
  "HOMETEAM_RUN_NETWORK_TESTS=$RUN_NETWORK_TESTS"
  "HOMETEAM_QA_WIDGET_SNAPSHOT_MODE=$SNAPSHOT_MODE"
  "TZ=UTC"
  "LANG=en_US_POSIX"
)
if [[ "$QA_STORAGE_MODE" == "isolated" ]]; then
  RUN_ENV+=("HOMETEAM_SHARED_CONTAINER_DIR=$SHARED_CONTAINER_ROOT")
fi

if ! env "${RUN_ENV[@]}" xcodebuild \
  -project "$ROOT_DIR/HomeTeam.xcodeproj" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  test \
  -only-testing:HomeTeamTests/WidgetSnapshotArtifactTests >"$LOG_PATH" 2>&1; then
  echo "FAIL: Widget snapshot generation test failed." >&2
  echo "Last test log lines:" >&2
  tail -n 60 "$LOG_PATH" >&2
  exit 1
fi

if ! xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$ATTACHMENT_EXPORT_DIR" >/dev/null 2>&1; then
  echo "FAIL: Unable to export widget snapshot attachments from result bundle." >&2
  echo "Result bundle: $RESULT_BUNDLE" >&2
  exit 1
fi

TEST_MANIFEST_PATH="$OUT_DIR/manifest.json"
XCRESULT_MANIFEST_PATH="$ATTACHMENT_EXPORT_DIR/manifest.json"
if [[ ! -f "$XCRESULT_MANIFEST_PATH" ]]; then
  echo "FAIL: xcresult attachment manifest missing at $XCRESULT_MANIFEST_PATH." >&2
  exit 1
fi

if [[ "$SNAPSHOT_MODE" == "coverage" ]]; then
  for sport_token in "${EXPECTED_SPORT_TOKENS[@]}"; do
    if ! jq -e --arg prefix "widget-${sport_token}-large_" '
      [.[].attachments[]?.suggestedHumanReadableName] as $names
      | any($names[]; startswith($prefix))
    ' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
      echo "FAIL: Missing live widget snapshot attachment for sport lane: $sport_token" >&2
      echo "Manifest: $XCRESULT_MANIFEST_PATH" >&2
      exit 1
    fi
  done
else
  if ! jq -e '
    [.[].attachments[]?.suggestedHumanReadableName] as $names
    | any($names[]; startswith("widget-prod-"))
  ' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
    echo "FAIL: Missing prod-parity widget snapshot attachment(s)." >&2
    echo "Manifest: $XCRESULT_MANIFEST_PATH" >&2
    exit 1
  fi
fi

if ! jq -e '
  [.[].attachments[]?.exportedFileName] | length >= 2
' "$XCRESULT_MANIFEST_PATH" >/dev/null; then
  echo "FAIL: Expected at least two exported snapshot attachments." >&2
  exit 1
fi

HASH_MANIFEST_PATH="$OUT_DIR/hash_manifest.json"

PNG_COUNT="$(find "$OUT_DIR" -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$PNG_COUNT" -lt 1 ]]; then
  echo "FAIL: No widget snapshot PNG artifacts were generated." >&2
  echo "Test log: $LOG_PATH" >&2
  exit 1
fi

{
  echo "{"
  echo "  \"timestamp\": \"$TIMESTAMP\","
  echo "  \"result_bundle\": \"$RESULT_BUNDLE\","
  echo "  \"files\": ["

  first_file=1
  while IFS= read -r png_file; do
    sha256="$(shasum -a 256 "$png_file" | awk '{print $1}')"
    file_name="$(basename "$png_file")"
    if [[ "$first_file" -eq 1 ]]; then
      first_file=0
    else
      echo ","
    fi
    printf '    {"file":"%s","sha256":"%s"}' "$file_name" "$sha256"
  done < <(find "$OUT_DIR" -type f -name '*.png' | sort)
  echo
  echo "  ]"
  echo "}"
} > "$HASH_MANIFEST_PATH"

{
  echo "timestamp=$TIMESTAMP"
  echo "result_bundle=$RESULT_BUNDLE"
  echo "test_log=$LOG_PATH"
  echo "snapshot_manifest=$TEST_MANIFEST_PATH"
  echo "hash_manifest=$HASH_MANIFEST_PATH"
  echo "xcresult_attachments=$ATTACHMENT_EXPORT_DIR"
  echo "xcresult_manifest=$XCRESULT_MANIFEST_PATH"
  echo "snapshot_png_count=$PNG_COUNT"
} > "$OUT_DIR/metadata.txt"

echo "Widget snapshot artifacts:"
echo "  $OUT_DIR"
if [[ -f "$TEST_MANIFEST_PATH" ]]; then
  echo "  $TEST_MANIFEST_PATH"
fi
echo "  $HASH_MANIFEST_PATH"
echo "  $ATTACHMENT_EXPORT_DIR"
echo "  $XCRESULT_MANIFEST_PATH"
echo "  $OUT_DIR/metadata.txt"
find "$OUT_DIR" -type f -name '*.png' | sort
