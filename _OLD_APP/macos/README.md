# HomeTeam macOS Shell

This directory scaffolds a native macOS app + WidgetKit extension for local-first use.

## Prerequisites
- Install full Xcode (not only Command Line Tools)
- Optional: Homebrew `xcodegen` (not required here; local binary is included at `./tools/xcodegen`)

## Generate project
```bash
cd macos
./tools/xcodegen generate
open HomeTeam.xcodeproj
```

## First run checklist
1. In Xcode, set your Team for both targets.
2. Keep **Automatically manage signing** enabled.
3. Build and run `HomeTeamApp`.
4. In app Settings, enable **Open at Login**.

## QA modes
- CI-first (no local prompts): GitHub Actions workflow `HomeTeam UI QA`
  - Runs widget + frontend snapshot QA on PRs and uploads artifacts.
  - **workflow_dispatch** on the same workflow also runs `HomeTeamUITests` (needs Apple code signing on the runner).
- Regression history + test-retirement candidates: GitHub Actions workflow `HomeTeam Regression Telemetry`
  - Appends test telemetry to `qa-history` branch and regenerates candidate reports from `qa/test-retirement-policy.json`.
- Local QA scripts are blocked by default to avoid macOS cross-app privacy prompts.
  - Developer override: `HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 ./scripts/qa_frontend_ui.sh`
  - UI / screen automation: `HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 ./scripts/qa_ui_tests.sh` (full `HomeTeamUITests` via `desktop_automation_gate.sh`; requires signing). Optional `HOMETEAM_UI_TESTS_ONLY=HomeTeamUITests/HomeTeamFrontendUITests`.
  - App Group / widget JSON checks: `HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 ./scripts/qa_ui_tests_real_app_group.sh` (optional `HOMETEAM_UI_TEST_DESTRUCTIVE_RESET=1` — QA macOS user only). See `AGENTS.md`.
  - Open installed app through gate: `HOMETEAM_DESKTOP_AUTOMATION_QA=1 ./scripts/desktop_automation_gate.sh open -a HomeTeam`

## Dock icon
1. Save a square dark-compatible logo as either:
   - `Assets/Logo.png` (preferred)
   - `macos/assets/Logo.png` (fallback)
2. Generate app icon sizes:
```bash
./scripts/generate_appicon.sh
```
3. Rebuild app target.

## What is implemented now
- SwiftUI app shell with basic game list + manual refresh
- `Open at Login` toggle via `SMAppService.mainApp`
- Local per-target snapshot storage (Personal Team friendly)
- Widget timeline policy scaffold (5 min when live, daily otherwise)
- Widget fetches ESPN data directly on timeline refresh

## Next implementation steps
- Expand widget UI to closely match the mac app scoreboard style
- Add calendar deep-link action from app rows
- Add richer error/offline states and telemetry logging
