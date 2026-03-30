# HomeTeam — Claude Instructions

## Autonomy expectations

When completing any task that involves code changes:
1. **Build** — always run `xcodebuild` and confirm it succeeds
2. **Test** — run unit tests; fix any failures before proceeding
3. **Kill old processes** — `pkill -x HomeTeam; pkill -f HomeTeamExtension` so the new binary takes effect
4. **Push** — `git push origin main`

Do all of this without asking the user. The user should never need to manually build, kill processes, or push.

## Project

macOS menu bar app with WidgetKit widget extension. Shows upcoming/live sports games for
favourite teams. Supports NHL, NFL, MLB, NBA, MLS, Premier League, F1, MotoGP.

## Key identifiers

| Thing | Value |
|---|---|
| Main app bundle ID | `com.hometeam.app` |
| Widget extension bundle ID | `com.hometeam.app.extension` |
| App Group | `group.com.hometeam.shared` |
| Team ID | `Q4MZVR4MU5` |
| Deployment target | macOS 14.0 |

## Build commands

```bash
# Standard build (use this — handles provisioning automatically)
xcodebuild -project macos/HomeTeam.xcodeproj -scheme HomeTeam -configuration Debug -allowProvisioningUpdates build

# Run unit tests only (fast, no network)
xcodebuild -project macos/HomeTeam.xcodeproj -scheme HomeTeam -configuration Debug -allowProvisioningUpdates test -only-testing HomeTeamTests

# Regenerate xcodeproj from project.yml (requires xcodegen at macos/tools/xcodegen)
# WARNING: xcodegen wipes entitlements files to <dict/> on every run.
# After regenerating, ALWAYS restore entitlements from git or manually:
#   Config/HomeTeam.entitlements          — application-groups: group.com.hometeam.shared
#   Config/HomeTeamExtension.entitlements — app-sandbox: true + application-groups: group.com.hometeam.shared
cd macos && ../macos/tools/xcodegen generate --spec project.yml
```

## Project layout

```
macos/
  HomeTeamApp/          — menu bar app (SwiftUI, AppKit)
  HomeTeamExtension/    — WidgetKit widget
  Shared/
    Models/             — HomeTeamGame, TeamCatalog, AppSettings, ScheduleSnapshot
    Services/           — ScheduleRepository, ScheduleClient, parsers (ESPN, MotoGP)
    Persistence/        — AppGroupStore, ScheduleSnapshotStore, AppSettingsStore
  Tests/                — Unit tests (StreamingFilterTests.swift)
  UITests/              — XCUITest (HomeTeamUITests.swift)
  Config/               — .entitlements files
  project.yml           — xcodegen spec (source of truth for project structure)
AppGroupSmokeTest/      — Throwaway 2-target project proving App Group plumbing works
QA_MASTER.MD            — Cross-project QA strategy (philosophy, bug handling, regression rules)
QA_HOMETEAM.md          — HomeTeam-specific test plan (layers, fixtures, engineering rules)
REQUIREMENTS.md         — Product requirements
WIDGET_APPGROUP_DEBUGGING.md — Provisioning dead-ends log (resolved as of 2026-03-26)
```

## Architecture rules (from QA_HOMETEAM.md)

1. **One normalization path** — all streaming service names go through `StreamingServiceMatcher.canonicalKey()`
2. **Injectable `now: Date`** — all date-sensitive filtering functions accept `now` as a parameter
3. **Widget view is pure** — `HomeTeamWidgetEntryView` takes only `HomeTeamEntry`, no stores
4. **App Group writes are synchronous and verified** — `AppGroupStore.write()` throws on failure
5. **Accessibility identifiers are a contract** — don't rename without updating UI tests
6. **Racing session filter must be explicit** — racing sports use sport-level filtering, not homeTeamID matching
7. **Snapshot reference images are committed** — snapshot tests use committed fixtures

## Provisioning

**DO NOT** use "Download Manual Profiles" in Xcode Settings → Accounts — this regenerates
profiles from the portal and has previously wiped App Groups capability.

Always build with `-allowProvisioningUpdates` from the command line, or let Xcode automatic
signing resolve profiles through Signing & Capabilities tab.

To verify the extension has App Groups in its embedded profile:
```bash
security cms -D -i \
  ~/Library/Developer/Xcode/DerivedData/HomeTeam-*/Build/Products/Debug/HomeTeam.app/\
Contents/PlugIns/HomeTeamExtension.appex/Contents/embedded.provisionprofile \
  | plutil -p - | grep -A5 "application-groups"
```
Should show `group.com.hometeam.shared`.

## App Group container

```
~/Library/Group Containers/group.com.hometeam.shared/
  schedule_snapshot.json   — written by app, read by widget
  app_settings.json        — written by app, read by widget (streaming filter)
```

## Racing sports note

F1 and MotoGP games in the snapshot have `homeTeamID = ""` and `awayTeamID = ""`.
The widget and any game-filtering code must use `sport == team.sport` to match racing
events, not `homeTeamID == espnTeamID`. Use `SupportedSport.isRacing` to branch.

## QA structure

- **`QA_MASTER.MD`** — universal QA standards: bug handling (reproduce before fixing), regression rules, change impact checks, definition of done. Applies to all projects.
- **`QA_HOMETEAM.md`** — this project's test plan: layer breakdown, test tables, fixtures, engineering rules. Implements the master strategy for HomeTeam specifically.

When writing tests or handling bugs, follow the master strategy. When looking up specific test cases or layer definitions, use the HomeTeam plan.

## Test coverage status

See `QA_HOMETEAM.md` for full spec. Current coverage ~20%:
- Layer 1B/1C streaming filter — covered (`StreamingFilterTests.swift`)
- Layer 1G snapshot merge — covered
- Layers 1D, 1E, 1F, 1I — 0% (functions not yet implemented)
- Layer 2 snapshot/preview tests — 0%
- Layer 3 UI tests — ~20%
- Layer 4 network smoke tests — 0%

Known structural gap: `qa_unit_gate.sh` does not build `HomeTeamExtension` target.
Extension build errors can hide silently in CI.
