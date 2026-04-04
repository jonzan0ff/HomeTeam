# Requirements: HomeTeam

> Derived from: `AGENTS.md`, `README.md`, and full audit of all source files as of March 2026.
> This doc states **what** the product does and **why**. Implementation detail lives in code.
> New requirements added during rebuild are marked **[NEW]**.

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

## Autonomy expectations

When completing any task that involves code changes:
1. **Build** — always run `xcodebuild` and confirm it succeeds
2. **Test** — run unit tests; fix any failures before proceeding
3. **Kill old processes** — `pkill -x HomeTeam; pkill -f HomeTeamExtension` so the new binary takes effect
4. **Push** — `git push origin main`

Do all of this without asking the user.

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
```

## Provisioning

**DO NOT** use "Download Manual Profiles" in Xcode Settings → Accounts — this regenerates profiles from the portal and has previously wiped App Groups capability.

Always build with `-allowProvisioningUpdates` from the command line, or let Xcode automatic signing resolve profiles through Signing & Capabilities tab.

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

F1 and MotoGP games in the snapshot have `homeTeamID = ""` and `awayTeamID = ""`. The widget and any game-filtering code must use `sport == team.sport` to match racing events, not `homeTeamID == espnTeamID`. Use `SupportedSport.isRacing` to branch.

---

## 1. Product overview

HomeTeam is a macOS menubar/dock app with a companion WidgetKit widget. It lets sports fans follow their favorite teams and racing drivers without opening a browser — schedules, scores, and streaming info in one glance.

---

## 2. Supported sports and data sources

| Sport | API | Notes |
|---|---|---|
| NHL | ESPN schedule + NHL Standings | Standings used to backfill missing records |
| MLB | ESPN schedule | |
| NFL | ESPN schedule | Two season types (regular=2, playoff=3) × two seasons fetched |
| NBA | ESPN schedule | |
| MLS | ESPN schedule | |
| Premier League | ESPN schedule | |
| F1 | ESPN racing schedule | Driver entities, not constructor teams |
| MotoGP | MotoGP PulseLive + ESPN fallback | PulseLive preferred; ESPN fallback |

Schedule URL pattern: `https://site.api.espn.com/apis/site/v2/sports/{sportPath}/{leaguePath}/teams/{id}/schedule`

---

## 3. Logo hosting [NEW]

All team and streaming provider logos are served from GitHub Pages, not ESPN or Google Favicon CDN.

- **Team logos**: `https://jonzan0ff.github.io/HomeTeam/logos/teams/{sport}_{espnTeamID}.png`
- **Racing logos**: `https://jonzan0ff.github.io/HomeTeam/logos/teams/{sport}_{espnTeamID}.{png,svg}`
- The app prefetches logos into the App Group container on each refresh (`ScheduleRepository.prefetchLogos` / `prefetchRacingLogos`). The widget reads cached files directly — no network calls.
- If a logo file is missing, the UI falls back to circle-initial (widget) or text abbreviation (app).
- Logo URLs are constructed at runtime from sport + espnTeamID, not embedded in catalogs.

---

## 3b. Logo asset pipeline [NEW]

Logo assets are built **once** as a pre-release tool, not fetched at app runtime. The output is a set of static files hosted on the HomeTeam server.

### Sources

Logo PNG/SVG files are committed to the `logos/teams/` directory in the repo and served via GitHub Pages at `https://jonzan0ff.github.io/HomeTeam/logos/teams/`.

### Naming convention
- Team sports: `{sport}_{espnTeamID}.png` (e.g. `nhl_23.png`)
- F1: `f1_{espnTeamID}.{svg,png}` (SVG preferred, PNG fallback)
- MotoGP: `motoGP_{espnTeamID}.png`

### App/widget behavior
- `ScheduleRepository.prefetchLogos` downloads missing team logos on each refresh into the App Group container
- `ScheduleRepository.prefetchRacingLogos` downloads logos for favorites AND all drivers in race results
- Stale logos (>7 days) are re-downloaded automatically
- Widget reads cached files from the App Group container — no network calls at render time
- If a logo file is missing: circle-initial fallback (widget) or text abbreviation (app)

### Ongoing maintenance
Add new logo files to `logos/teams/` and push when:
- A new team or sport is added to the catalog
- A team rebrands (new logo)

---

## 4. App — core surfaces

### 4.1 Main scoreboard window

**Window minimum size**: 560 × 440 pt.

**Background**: dark navy gradient (top-leading to bottom-trailing) with a subtle red radial glow at top-left.

**Layout**:
- Scrollable list of team sections, one per favorite, in user-defined order
- Footer bar at bottom (always visible, outside scroll)
- Runtime Status indicator floating at bottom-right
- Onboarding overlay when setup is incomplete

**Empty states** (mutually exclusive, checked in order):

| Condition | Icon | Message |
|---|---|---|
| No favorites configured | `star` | "Add favorite teams in Settings" |
| Favorites exist but all games filtered/hidden | `tv` | "No games available" |

When games exist, the scrollable section list is shown.

**Context menu**: right-click anywhere on the main window shows "Settings..." which opens the Settings window.

**Auto-open Settings on first launch**: on first launch where `needsOnboarding` is true and Settings has not yet been auto-opened, the app automatically opens Settings routed to the Favorite Teams section. This happens once per onboarding cycle (stored in `UserDefaults`).

### 4.2 Team scoreboard block

One block per favorite team, in favorites order.

```
[Team Display Name]  [Summary stats inline]
PREVIOUS
  [card] [card] [card]
UPCOMING
  [card] [card] [card]
```

- Team name: `.subheadline.weight(.semibold)`, white 90% opacity
- Summary stats: `.caption2.weight(.medium)`, white 62% opacity, single line
- Section labels ("PREVIOUS", "UPCOMING"): `.caption2.weight(.bold)`, uppercased, 1pt letter spacing, white 64% opacity
- Block background: subtle white fill with border, corner radius 14

**Empty row placeholder**: "No final games yet." / "No upcoming games." — caption size, white 68% opacity, inside a lightly filled rounded rect.

### 4.3 Scoreboard game card

Cards displayed in a **3-column LazyVGrid** per section.

**Card header** (same structure as widget):
- Left chip: date label ("MAR 25"), capsule background
- Right text: scheduled time | compact live status | compact race name

**Live game card**: border changes from white 16% opacity to **red 55% opacity** — the only card with a colored border.

**Card body** (standard sports):
- Away team row: logo (16×16 pt) + 3-char abbreviation + score or record
- Home team row: same
- Leader row: **bold** weight + visible left-pointing triangle indicator; non-leader triangle is invisible (opacity 0) but occupies the same space to prevent layout shift

**Card body** (racing, final with results):
- `RacingResultLine` rows: place number + team logo + `{driver} {full team name}`
- Favorite driver row: bold weight + white color
- Non-favorite: regular weight + white 88% opacity

**Card body** (racing, upcoming, no team abbreviations):
- Race event name (`homeTeam` field), `.caption.weight(.semibold)`

**Card footer** (upcoming cards only):
- Left: streaming service badge
- Right: Google Calendar button (see 4.4)

**Score/record display logic**:

| Row type | Game status | Sport | Shows |
|---|---|---|---|
| Upcoming | Scheduled | F1 or MotoGP | empty string (no record) |
| Upcoming | Scheduled | All others | team record (e.g. "32-28-10") |
| Upcoming | Live | Any | score |
| Previous | Any | Any | score if available, else record, else "-" |

### 4.4 Google Calendar button

Appears on each **upcoming** game card footer (right side).

- Icon: `calendar` SF Symbol, 11pt semibold
- Background: white 10% opacity, rounded rect corner radius 6
- **Hover state**: background brightens to white 24% opacity; icon scales up 5% (`scaleEffect(1.05)`); both animate with `.easeInOut(duration: 0.15)`
- Tooltip: "Add to Google Calendar"
- Action: opens `game.googleCalendarURL` in the default browser

**Google Calendar URL structure**:
- Action: `TEMPLATE`
- Title: `{awayTeam} at {homeTeam}`
- Start: `startTimeUTC` in UTC, format `yyyyMMdd'T'HHmmss'Z'`
- End: start + 3 hours
- Details & Location: `"Watch on {streamingServices comma-separated}."`

### 4.5 Footer bar

Always visible at the bottom of the main window.

- **"Updated HH:MM"** timestamp (local time, omits date). On each successful refresh, the text **flashes bold and white for 900ms** then returns to normal weight and 70% opacity. Animation is `.easeInOut(duration: 0.18)`.
- **Refresh button**: `arrow.clockwise` icon, 11pt semibold, white 90% opacity, rounded rect background. Tooltip: "Refresh now". Triggers an immediate refresh of all tracked teams.

### 4.6 Auto-refresh policy (main app)

The app runs a background refresh loop from launch. Interval is determined after each refresh:

| Condition | Interval |
|---|---|
| Any tracked team has a live game | 60 seconds |
| Otherwise | 60 minutes |

This is distinct from the widget's refresh policy (5.3).

### 4.7 Runtime Status indicator

> **Status: Not implemented.** `RuntimeIssueCenter` existed in `_OLD_APP/` but was not carried forward to the current codebase. Errors are logged via `print()` to stdout only.

---

## 5. Widget

### 5.1 Configuration — auto-prompt on add [NEW + UPDATED]

The widget uses `AppIntentConfiguration` with a `@Parameter(default: nil)` for the team selection. This means:

**On widget placement**: macOS automatically presents the configuration sheet immediately. The user picks a team from the list before the widget renders live data. No "right-click to edit" discovery required.

**Requirements for this to work**:
1. The App Group `app_settings.json` must contain at least one entry in `favoriteTeamCompositeIDs` at the time the user adds the widget. If the list is empty, the picker shows all teams.
2. The picker shows favorites first (prioritized), then all other teams.
3. Onboarding must block completion until the App Group file is written with at least one favorite — this is the gate that makes the widget picker useful from the first add.

**Unconfigured widget deep link**: Not yet implemented. Planned: tapping an unconfigured widget opens the app via URL scheme `hometeam://settings/favorites`.

### 5.2 Configuration picker behavior

- Picker entity type: `TeamWidgetEntity` backed by `TeamCatalog`
- Uses `EntityQuery` (not `EntityStringQuery`) — macOS string-query path is unreliable for large entity lists
- Favorites appear first; recents surface above the rest
- If the configured team ID is no longer in the catalog, falls back gracefully to the default team

### 5.3 Refresh policy

| Condition | Interval |
|---|---|
| Any game in snapshot is live | 60 seconds |
| Upcoming game exists | min(game start time, 30 minutes) |
| No live or upcoming games | 30 minutes |

### 5.4 Widget layout (systemLarge only)

```
[Team Name]  [Summary stats]
─────────────────────────────
P ┌────────┐ ┌────────┐
R │ card 1 │ │ card 2 │
E └────────┘ └────────┘
V
U ┌────────┐ ┌────────┐ ┌────────┐
P │ card 1 │ │ card 2 │ │ card 3 │
C └────────┘ └────────┘ └────────┘
                         Updated HH:MM
```

Padding: 10pt all sides. Spacing: 6pt between header elements, 2pt between sections.

**Title**: `.system(size: 13, weight: .bold)`, primary color, single line
**Summary**: `.system(size: 10.5, weight: .medium)`, white 62% opacity (dark) / secondary (light), single line
**Section labels**: vertical rotated text, `.system(size: 7.5, weight: .heavy)`, uppercased, white 30% opacity (dark) / secondary 45% (light), positioned left of card row
**Timestamp**: `.system(size: 8.5, weight: .regular)`, white 55% opacity (dark) / secondary (light), right-aligned

### 5.5 Widget game card

Smaller than the app card (designed for widget density).

**Card header**:
- Left chip: date ("MAR 25"), 9pt bold, capsule, width 37pt
- Right: scheduled time (8pt semibold) | live status | race name

**Card body — standard sports**:
- Team rows: 12×12 pt logo + 3-char abbreviation + score/record
- Leader indicator: same left-pointing triangle pattern as app

**Card body — racing, final with results** (`WidgetRacingResults`):
- Place (8pt) + 12×12 logo + `{driver} {teamAbbrev}` (8pt)
- Note: widget uses `teamAbbrev`, app uses full team name

**Card body — racing, upcoming scheduled** (no abbreviations):
- Race name text (8.5pt semibold), 2-line limit

**Card footer** (upcoming only):
- Streaming service badge only — no calendar button in the widget

**Card background**: white 9% opacity, rounded rect corner radius 9, white 14% border.

### 5.6 Widget empty and error states

All states display as a `VStack` replacing the Previous/Upcoming sections entirely.

| Condition | Title | Detail |
|---|---|---|
| No team configured, no favorites in app | "Add favorites in HomeTeam" | "Then right-click this widget and choose Edit \"HomeTeam\"." |
| No team configured, favorites exist | "Widget not configured" | "Right-click this widget and choose Edit \"HomeTeam\"." |
| API error | "Unable to load games" | Error message string |
| All upcoming hidden by streaming filter | "Upcoming hidden by streaming filters" | "Open HomeTeam Settings and add providers that carry this team, or broaden your streaming picks." |
| Games exist but none qualify as previous/upcoming | "Schedule is still catching up" | "The feed has events that are not shown as previous or upcoming yet. Open HomeTeam to refresh." |
| Truly empty | "No games available" | "Open HomeTeam to refresh. To choose which favorite this widget follows, right-click it and choose Edit \"HomeTeam\"." |

**Empty section placeholders** (when only one section is empty):
- Previous empty: "No finals"
- Upcoming empty (no filter): "No upcoming"
- Upcoming empty (streaming filter active): "None match your streaming picks"

---

## 6. Sport-specific display logic

### 6.1 Team sports (NHL, MLB, NFL, NBA, MLS, Premier League)

**Summary bar** (`HomeTeamTeamSummary`, style `.standard`):
```
{record}  |  {place}  |  L10 {last10}  |  {streak}
```
Example: `32-28-10  |  7th  |  L10 4-6-0  |  W2`

**Previous row**: finalized games, most recent first. Card shows home/away abbreviations, final scores. Header right: "Final".

**Upcoming row**: scheduled + live games, streaming-filtered. Card shows abbreviations and records. Header right: local scheduled time.

### 6.2 Racing — F1

**Summary bar** (`HomeTeamTeamSummary`, style `.racingDriver`):
```
Place {place}  |  Pts {record}  |  Wins {last10}  |  Podiums {streak}
```

**Previous row**: finalized F1 events filtered to inferred season year (14). Card body shows `RacingResultLine` rows if present. **No session-type filter** — all finalized F1 sessions appear (including practice, qualifying).

**Upcoming row**: all non-final F1 events. **No session-type filter** — practice, qualifying, sprint, and GP all appear. Card shows race name when no abbreviations present.

### 6.3 Racing — MotoGP

**Summary bar**: same `.racingDriver` style as F1.

**Previous row**: finalized MotoGP events filtered to inferred season year (14).

**Upcoming row — SESSION FILTER APPLIED**. Only sessions whose `homeTeam` name matches:
- Contains `"sprint"` → show
- Contains `"grand prix"` OR ends with `" gp"` → show
- Equals `"race"` OR contains `" main race"` → show
- Everything else (practice, qualifying, warm-up, test) → **exclude**

> **Intentional gap vs F1**: F1 has no equivalent session filter for upcoming. This is a known difference to revisit (see 16).

### 6.4 Race name formatting (compact display)

Applied to the `homeTeam` field for F1/MotoGP finalized events shown in card headers.

Priority order:
1. `{X} Grand Prix` → `{X} GP`
2. `Grand Prix of {X}` → `{X} GP`
3. `{X} GP` → `{X} GP`
4. Strip: `Formula 1`, `MotoGP`, year (`20XX`), word `of`; replace `Grand Prix` → `GP`
5. Strip known sponsor prefixes: Qatar Airways, Heineken, Aramco, Gulf Air, STC, Crypto.com, Lenovo, MSC Cruises, Pirelli, AWS, Tag Heuer, Etihad Airways, Singapore Airlines

Examples:
- `"Qatar Airways Australian Grand Prix"` → `"Australian GP"`
- `"Formula 1 Bahrain Grand Prix 2024"` → `"Bahrain GP"`
- `"MotoGP Grand Prix of Spain"` → `"Spain GP"`

### 6.5 Live status compact label

Applied to `statusDetail` string for live games:

| Raw detail | Compact |
|---|---|
| Contains "SHOOTOUT" | `SO` |
| `END OF THE 2ND PERIOD INTERMISSION` | `2ND INT` |
| `END 3RD` | `3RD INT` |
| Contains "INTERMISSION" (catch-all) | `INT` |
| Has period + clock | `2ND • 14:32` |
| Has period only | `2ND` |
| Has clock only | `14:32` |
| Empty | `LIVE` |

---

## 7. Streaming filter

### 7.1 Service normalization

All streaming service names — from the API, from user settings, and from provider catalogs — pass through a **single normalization function** before any comparison. No secondary normalization at render time.

| Canonical token | Matches |
|---|---|
| `hulu tv` | "Hulu TV", "Hulu Live TV", "Hulu + Live TV" |
| `hulu` | "Hulu" (without live/tv suffix) |
| `espn+` | "ESPN+", "ESPN Plus" |
| `paramount` | "Paramount+", "Paramount Plus" |
| `amazon` | "Amazon Prime Video", "Prime Video", "Amazon" |
| `peacock` | "Peacock", "Peacock Premium" |
| `hbo` | "HBO", "Max", "TNT", "TBS", "TruTV", "Bleacher Report", "B/R Sports" |
| `apple tv` | "Apple TV+", "AppleTV+", "TV+" |
| `youtube tv` | "YouTube TV" |
| `netflix` | "Netflix" |

### 7.2 Filter behavior

- **No services selected** → all upcoming games pass (show everything)
- **Services selected** → game passes only if ≥1 of its streaming services normalizes to a selected canonical token
- **Unrecognized services** (e.g. "Regional Sports Network") → fail when any services are selected; pass when none selected
- Streaming filter applies to **upcoming only** — previous results are never filtered

### 7.3 Preferred service display

When a game has multiple services:
1. First matched service that is in the user's selected set
2. If no match: first recognized (matched) service
3. If no recognized services: raw first service string
4. If no services at all: "Stream" (widget) / "TV" (app)

### 7.4 Streaming service sort in Settings

In the Streaming Services settings section, providers are sorted: **selected providers first** (alphabetical within selected), then unselected (alphabetical). Sort updates live as toggles change.

### 7.5 Streaming badge colors

| Service | Badge label | Background color |
|---|---|---|
| Hulu TV / Hulu | HULU TV / HULU | Green `(0.09, 0.74, 0.46)` |
| ESPN+ | ESPN+ | Red `(0.79, 0.14, 0.16)` |
| Paramount | PARAMOUNT+ | Blue `(0.10, 0.40, 0.85)` |
| Amazon/Prime | PRIME | Blue `(0.12, 0.46, 0.82)` |
| Peacock | PEACOCK | Orange `(0.95, 0.58, 0.10)` |
| HBO/Max | HBO | Purple `(0.45, 0.26, 0.85)` |
| Apple TV | TV+ | White 22% opacity (+ Apple logo icon) |
| YouTube TV | YT TV | Red `(0.86, 0.16, 0.16)` |
| Netflix | NETFLIX | Red `(0.78, 0.12, 0.16)` |
| Unknown | first 10 chars | White 20% opacity |

Badge text uses `.rounded` design, `.black` weight. Font size 8.5pt, or 7.5pt if label >8 chars.

---

## 8. Settings

**Window minimum size**: 860 × 640 pt.

**Layout**: 220pt-wide sidebar + detail panel. Sidebar shows section name; selected section highlighted with accent color 18% opacity background.

### 8.1 Favorite Teams section

- Lists current favorites with drag handle, team name, sport label, "Hide During Off-season" checkbox, trash button
- **Cannot delete the last remaining favorite** — trash button hidden when only 1 favorite exists
- **Drag-to-reorder**: live re-order via `DropDelegate`; order saved immediately
- **Add Team**: Sport picker (menu style) + Team/Driver picker (menu style) + "Add Team" button. Team picker resets to first available team when sport changes.
- **"Reset Setup..." button** (destructive, top-right of section): confirmation dialog before executing. Clears `favoriteTeamCompositeIDs`, `selectedStreamingServices`, `hideDuringOffseasonTeamCompositeIDs`. Re-triggers onboarding.

### 8.2 Streaming Services section

- Checkbox grid (`adaptive(minimum: 170)` columns, 8pt spacing)
- Each provider has a stable `accessibilityIdentifier`: `settings.streaming.toggle.{provider.id}`
- Shows count: "Selected: N" below heading
- Sort: selected first, then alphabetical (7.4)

### 8.3 Location section

- ZIP code text field (150pt wide, numeric, max 5 digits)
- **Auto-resolve on complete entry**: when input reaches 5 digits, resolution begins automatically. Shows "Resolving ZIP..." while pending.
- **Resolution chain**: Zippopotam API first, CLGeocoder fallback if that fails
- On success: shows "Resolved to {City}, {ST}." and stores city + state in settings
- On failure: shows error message ("Enter a valid 5-digit ZIP code." / "ZIP code not found.")
- Existing city/state shown as "Current: {city}, {state}" or "Current: Not set"
- Location is **optional** — not required for onboarding completion

### 8.4 Notifications section

| Toggle | Label | Notes |
|---|---|---|
| Game Start Reminders | "Game Start Reminders (Watchable Only)" | Only fires for games on user's selected streaming services |
| Final Scores | "Final Scores (All Games)" | Fires for all tracked teams |

Divider below, then:

| Toggle | Label | Notes |
|---|---|---|
| Open at Login | "Open at Login" | Via `SMAppService.mainApp` |

"Open at Login" shows a status message from `LoginItemManager` below the toggle (e.g. registration error if entitlements are misconfigured).

### 8.5 About section

- Heading: "Test build version"
- Value: `AppTestVersion.displayString` in monospaced font, text-selectable
- Format: `0.00X (Mon DD HH:MM)` — bumped +0.001 per test handoff
- Subtitle: clarifies this is not the Xcode bundle version

---

## 9. Onboarding

**Trigger**: shown as an overlay on the main window whenever `needsOnboarding` is true (i.e. favorites list is empty OR no streaming services selected).

**Layout**: modal card (max 640pt wide), system window background, drop shadow.

**Checklist rows** (3 items):

| Row | Required | Complete state |
|---|---|---|
| Favorite Teams | Yes | Checkmark turns green; subtitle: "At least one favorite is selected." |
| Streaming Services | Yes | Checkmark turns green; subtitle: "At least one provider is selected." |
| Location | No | Checkmark turns green when ZIP resolved to city/state; subtitle shows "City, ST" |

Incomplete row: empty circle icon, subtitle "Required" or "Optional for onboarding".

**Buttons**:
- "Open Settings" → opens Settings, routed to Favorite Teams
- "Refresh Setup Status" → re-reads settings from store (tooltip: "Use this after updating settings from another window.")
- Each checklist row has its own "Open {Section}" button

**Auto-dismiss**: overlay disappears as soon as `needsOnboarding` becomes false — no manual dismiss needed.

**Overlay background**: `Color.black.opacity(0.35)` behind the card.

---

## 10. Settings persistence and sync

- Settings stored as `app_settings.json` in the **shared App Group container** (accessible by both app and widget extension)
- **iCloud sync**: intentionally omitted — `ubiquity-kvstore-identifier` entitlement is not yet provisioned
- All settings writes trigger `WidgetCenter.shared.reloadAllTimelines()` so the widget reflects changes immediately
- Settings survive app relaunch; onboarding state survives relaunch

---

## 11. Data persistence and shared container

- **App Group container** is shared between app target and widget extension
- `app_settings.json`: `AppSettings` (favorites, streaming, location, notifications)
- `schedule_snapshot.json`: single `ScheduleSnapshot` containing all games across all sports
- **Non-destructive merge**: if a refresh returns an empty game list (no error), the prior cached game list is kept. Prevents stale-cache wipes from transient empty API responses.
- Widget reads settings and snapshot directly on timeline refresh — no IPC to app needed

---

## 12. Hide During Off-season

A team marked "Hide During Off-season" is suppressed from the main scoreboard when:
- No live game is active, **AND**
- The nearest upcoming game is **more than 45 days** away, **OR**
- There is no upcoming game AND the most recent final was **more than 30 days** ago

When hidden, the team's `TeamScheduleSection` is omitted entirely from the scroll list.

---

## 13. NFL season logic

NFL fetches **4 endpoints** per refresh:
- Active season + (active - 1) season x regular season (type 2) + playoffs (type 3)
- Active season = current year if month >= August, else current year - 1
- Deduplication by game ID after merge

---

## 14. Racing season year inference

For `previousGames`, racing sports filter to a single season year to avoid mixing seasons:

1. If there are upcoming races: use the year of the nearest upcoming race
2. Else if any race is in the current calendar year: use current year
3. Else: use the year of the most recent past race
4. If detection is ambiguous (multiple racing sports, or no signals): no year filter applied

---

## 15. Team logo display

**App (16x16 pt)**:
- Shows cached image at high interpolation if available
- Falls back to 3-char abbreviation text (no placeholder circle)

**Widget (12x12 pt)**:
- Shows cached image at high interpolation if available
- Falls back to a white-fill circle with the first character of the abbreviation

Both surfaces use the `TeamLogoStore` which fetches from the HomeTeam logo server (3) and caches in memory.

---

## 16. Known gaps and design decisions for rebuild

1. **F1 session filter missing**: MotoGP filters upcoming to GP/sprint/race only; F1 shows all sessions. Likely unintentional — decide whether to apply the same filter to F1.
2. **Widget is systemLarge only**: No medium or small variants.
3. **Racing previous has no session filter**: Finalized practice/qualifying results can appear as "previous" for both F1 and MotoGP.
4. **Streaming service list is hardcoded**: Adding a new provider requires a code change and a logo asset.
5. **Widget retry on error**: On API failure, widget uses stale cache but waits up to 24h for next retry unless a live game is detected.
6. **`hideDuringOffseasonTeamCompositeIDs` is fully implemented** (logic in `AppViewModel.isOutOfSeason`) but the enforcement only applies to the main app list — widget does not apply the same filter.
7. **Racing results in app vs widget differ**: App shows `{driver} {full team name}`; widget shows `{driver} {teamAbbrev}`. Decide on one canonical format.
8. **No "watchable" filter implementation visible**: Game Start Reminders are labeled "(Watchable Only)" but the watchable logic is not implemented in the current codebase — only the setting is stored.
