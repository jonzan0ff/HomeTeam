# QA Telemetry

This folder stores policy and long-run telemetry outputs for regression-test optimization.

## What gets stored
- `qa/history/test_runs.ndjson`: one row per `.xcresult` bundle run summary.
- `qa/history/test_cases.ndjson`: one row per test case execution.
- `qa/history/regression_candidates.json`: machine-readable candidate report.
- `qa/history/regression_candidates.md`: human-readable candidate report.

## Policy
- `qa/test-retirement-policy.json` controls thresholds and protected tests.
- Default thresholds:
  - demotion candidate: 1000+ runs, 0 failures
  - retire candidate: 10000+ runs, 0 failures

## Workflow
- CI collects telemetry from `.xcresult` bundles.
- CI appends records to `qa-history` branch.
- CI regenerates candidate reports after each append.
- PRs can consume report output, but only non-PR runs persist history.
