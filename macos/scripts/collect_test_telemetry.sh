#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <output-dir> [result-bundle.xcresult ...]" >&2
  exit 1
fi

OUTPUT_DIR="$1"
shift

RUNS_OUT="$OUTPUT_DIR/test_runs.ndjson"
CASES_OUT="$OUTPUT_DIR/test_cases.ndjson"

mkdir -p "$OUTPUT_DIR"
: > "$RUNS_OUT"
: > "$CASES_OUT"

declare -a RESULT_BUNDLES=()

if [[ $# -gt 0 ]]; then
  for candidate in "$@"; do
    if [[ -d "$candidate" ]]; then
      RESULT_BUNDLES+=("$candidate")
    else
      echo "WARN: Result bundle not found, skipping: $candidate" >&2
    fi
  done
else
  while IFS= read -r bundle; do
    RESULT_BUNDLES+=("$bundle")
  done < <(find /private/tmp /tmp -maxdepth 1 -type d -name "HomeTeam*.xcresult" 2>/dev/null | sort -u)
fi

if [[ ${#RESULT_BUNDLES[@]} -eq 0 ]]; then
  echo "FAIL: No result bundles provided or discovered." >&2
  exit 1
fi

COLLECTED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPOSITORY="${GITHUB_REPOSITORY:-local}"
WORKFLOW_NAME="${GITHUB_WORKFLOW:-local}"
WORKFLOW_RUN_ID="${GITHUB_RUN_ID:-local}"
WORKFLOW_RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
WORKFLOW_EVENT="${GITHUB_EVENT_NAME:-local}"
GIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
GIT_REF="${GITHUB_REF_NAME:-local}"
SOURCE_KIND="local"
if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
  SOURCE_KIND="ci"
fi

PROCESSED_BUNDLES=0

for bundle in "${RESULT_BUNDLES[@]}"; do
  summary_json="$(xcrun xcresulttool get test-results summary --path "$bundle" --compact 2>/dev/null || true)"
  if [[ -z "$summary_json" ]]; then
    echo "WARN: Could not read test summary from $bundle" >&2
    continue
  fi

  tests_json="$(xcrun xcresulttool get test-results tests --path "$bundle" --compact 2>/dev/null || true)"

  run_record_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  bundle_name="$(basename "$bundle")"

  echo "$summary_json" | jq -c \
    --arg run_record_id "$run_record_id" \
    --arg repository "$REPOSITORY" \
    --arg workflow_name "$WORKFLOW_NAME" \
    --arg workflow_run_id "$WORKFLOW_RUN_ID" \
    --arg workflow_run_attempt "$WORKFLOW_RUN_ATTEMPT" \
    --arg workflow_event "$WORKFLOW_EVENT" \
    --arg git_sha "$GIT_SHA" \
    --arg git_ref "$GIT_REF" \
    --arg source_kind "$SOURCE_KIND" \
    --arg collected_at_utc "$COLLECTED_AT_UTC" \
    --arg result_bundle "$bundle_name" \
    --arg result_bundle_path "$bundle" '
    {
      record_id: $run_record_id,
      repository: $repository,
      workflow_name: $workflow_name,
      workflow_run_id: $workflow_run_id,
      workflow_run_attempt: $workflow_run_attempt,
      workflow_event: $workflow_event,
      git_sha: $git_sha,
      git_ref: $git_ref,
      source_kind: $source_kind,
      collected_at_utc: $collected_at_utc,
      result_bundle: $result_bundle,
      result_bundle_path: $result_bundle_path,
      result: (.result // "Unknown"),
      total_tests: (.totalTestCount // 0),
      passed_tests: (.passedTests // 0),
      failed_tests: (.failedTests // 0),
      skipped_tests: (.skippedTests // 0),
      expected_failures: (.expectedFailures // 0),
      start_time_epoch: (.startTime // null),
      finish_time_epoch: (.finishTime // null),
      failure_messages: (
        (.testFailures // [])
        | map(.failureText // .message // .description // .text // "")
        | map(select(length > 0))
      )
    }' >> "$RUNS_OUT"

  if [[ -n "$tests_json" ]]; then
    echo "$tests_json" | jq -c \
      --arg run_record_id "$run_record_id" \
      --arg repository "$REPOSITORY" \
      --arg workflow_name "$WORKFLOW_NAME" \
      --arg workflow_run_id "$WORKFLOW_RUN_ID" \
      --arg workflow_run_attempt "$WORKFLOW_RUN_ATTEMPT" \
      --arg workflow_event "$WORKFLOW_EVENT" \
      --arg git_sha "$GIT_SHA" \
      --arg git_ref "$GIT_REF" \
      --arg source_kind "$SOURCE_KIND" \
      --arg collected_at_utc "$COLLECTED_AT_UTC" \
      --arg result_bundle "$bundle_name" '
      def test_cases(node):
        if (node.nodeType == "Test Case") then [node]
        else [ (node.children // [])[] | test_cases(.)[] ]
        end;

      .testNodes[]? | test_cases(.)[] | {
        record_id: ($run_record_id + ":" + (.nodeIdentifierURL // .nodeIdentifier // .name)),
        run_record_id: $run_record_id,
        repository: $repository,
        workflow_name: $workflow_name,
        workflow_run_id: $workflow_run_id,
        workflow_run_attempt: $workflow_run_attempt,
        workflow_event: $workflow_event,
        git_sha: $git_sha,
        git_ref: $git_ref,
        source_kind: $source_kind,
        collected_at_utc: $collected_at_utc,
        result_bundle: $result_bundle,
        test_identifier: (.nodeIdentifierURL // .nodeIdentifier // .name),
        test_name: (.name // ""),
        test_suite: ((.nodeIdentifier // "" | split("/") | .[0]) // ""),
        node_type: (.nodeType // ""),
        result: (.result // "Unknown"),
        duration_seconds: (.durationInSeconds // 0)
      }' >> "$CASES_OUT"
  fi

  PROCESSED_BUNDLES=$((PROCESSED_BUNDLES + 1))
done

if [[ ! -s "$RUNS_OUT" ]]; then
  echo "FAIL: No telemetry records were written." >&2
  exit 1
fi

echo "Telemetry collection complete:"
echo "  Bundles processed: $PROCESSED_BUNDLES"
echo "  Run rows:          $(wc -l < "$RUNS_OUT" | tr -d ' ')"
echo "  Test rows:         $(wc -l < "$CASES_OUT" | tr -d ' ')"
echo "  Output dir:        $OUTPUT_DIR"
