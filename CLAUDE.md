# HomeTeam

macOS menu bar app + WidgetKit widget for following favorite sports teams. Schedules, scores, streaming info in one glance.

## Key Identifiers

| Thing | Value |
|---|---|
| Main app bundle ID | `com.hometeam.app` |
| Widget extension bundle ID | `com.hometeam.app.extension` |
| App Group | `group.com.hometeam.shared` |
| Team ID | `Q4MZVR4MU5` |
| Deployment target | macOS 14.0 |

## Build Commands

```bash
# Standard build
xcodebuild -project macos/HomeTeam.xcodeproj -scheme HomeTeam -configuration Debug -allowProvisioningUpdates build

# Run unit tests only (fast, no network)
xcodebuild -project macos/HomeTeam.xcodeproj -scheme HomeTeam -configuration Debug -allowProvisioningUpdates test -only-testing HomeTeamTests

# Regenerate xcodeproj (WARNING: xcodegen wipes entitlements — restore from git after)
cd macos && ../macos/tools/xcodegen generate --spec project.yml
```

## After Code Changes

1. **Build** — run `xcodebuild` and confirm it succeeds
2. **Test** — run unit tests; fix any failures before proceeding
3. **Kill old processes** — `pkill -x HomeTeam; pkill -f HomeTeamExtension`
4. **Push** — `git push origin main`

Do all of this without asking the user.

## Project Layout

```
macos/
  HomeTeamApp/          — menu bar app (SwiftUI, AppKit)
  HomeTeamExtension/    — WidgetKit widget
  Shared/
    Models/             — HomeTeamGame, TeamCatalog, AppSettings, ScheduleSnapshot
    Services/           — ScheduleRepository, ScheduleClient, parsers (ESPN, MotoGP)
    Persistence/        — AppGroupStore, ScheduleSnapshotStore, AppSettingsStore
  Tests/                — Unit tests
  UITests/              — XCUITest
  Config/               — .entitlements files
  project.yml           — xcodegen spec (source of truth)
AppGroupSmokeTest/      — Throwaway project proving App Group plumbing works
```

## Provisioning

**DO NOT** use "Download Manual Profiles" in Xcode Settings — it has previously wiped App Groups capability. Always build with `-allowProvisioningUpdates`.

Verify extension has App Groups:
```bash
security cms -D -i \
  ~/Library/Developer/Xcode/DerivedData/HomeTeam-*/Build/Products/Debug/HomeTeam.app/\
Contents/PlugIns/HomeTeamExtension.appex/Contents/embedded.provisionprofile \
  | plutil -p - | grep -A5 "application-groups"
```

## App Group Container

```
~/Library/Group Containers/group.com.hometeam.shared/
  schedule_snapshot.json   — written by app, read by widget
  app_settings.json        — written by app, read by widget (streaming filter)
```

## Racing Sports Note

F1 and MotoGP games have `homeTeamID = ""` and `awayTeamID = ""`. Use `sport == team.sport` to match racing events, not `homeTeamID == espnTeamID`. Use `SupportedSport.isRacing` to branch.

## QA Routing — read this first

Before running any QA: **read `.claude/surfaces.md`**. It lists every surface (widget, menu bar popover, app views, data layer, etc.) with the file globs that belong to it and the exact QA commands to run when any of those files change. Use it as the authoritative routing table — run only the commands for the surfaces your diff touched, nothing else. The change-to-test table below is kept as a quick human reference but `surfaces.md` is the source of truth.

## Change-to-Test Mapping

| Changed files | Required tests |
|---|---|
| `Shared/Models/`, `Shared/Services/`, `Shared/Persistence/` | Unit tests (`HomeTeamTests`) |
| `HomeTeamExtension/`, widget views | Unit tests + snapshot tests |
| `HomeTeamApp/`, app views | Unit tests + visual QA (screenshot) |
| `Config/`, `project.yml`, entitlements | Build verification + App Group smoke test |
| `Tests/` only | Run the modified tests |
| `logos/`, docs, README | No tests required |

Full requirements in `.claude/rules/requirements.md`. Build verification plan in `.claude/rules/build-verification-plan.md`.
