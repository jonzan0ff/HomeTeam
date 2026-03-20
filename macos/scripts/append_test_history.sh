#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <current-telemetry-dir> <history-dir>" >&2
  exit 1
fi

CURRENT_DIR="$1"
HISTORY_DIR="$2"

mkdir -p "$HISTORY_DIR"

touch "$HISTORY_DIR/test_runs.ndjson"
touch "$HISTORY_DIR/test_cases.ndjson"

if [[ -s "$CURRENT_DIR/test_runs.ndjson" ]]; then
  cat "$CURRENT_DIR/test_runs.ndjson" >> "$HISTORY_DIR/test_runs.ndjson"
fi

if [[ -s "$CURRENT_DIR/test_cases.ndjson" ]]; then
  cat "$CURRENT_DIR/test_cases.ndjson" >> "$HISTORY_DIR/test_cases.ndjson"
fi

echo "History append complete:"
echo "  Runs history:  $HISTORY_DIR/test_runs.ndjson"
echo "  Cases history: $HISTORY_DIR/test_cases.ndjson"
