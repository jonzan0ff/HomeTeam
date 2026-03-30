# CLAUDE.md

This file governs all AI-assisted development for this project. It is divided into **shared standards** (identical across all projects) and **project-specific sections** (unique to this project).

---

## File Structure

```
CLAUDE.md (this file)
├── SHARED: Coding Standards        ← identical across all projects
├── SHARED: QA Master Standards     ← identical across all projects
├── SHARED: Tech Stack              ← identical across all projects
├── PROJECT: Requirements           ← unique to this project
└── PROJECT: QA Plan                ← unique to this project
```

### Synchronization Rules

The **shared sections** (Coding Standards, QA Master Standards, Tech Stack) must remain identical across all projects in `/jonzan0ff/`. When updating a shared section:

1. Make the edit in whichever project you're working in
2. Copy the updated shared sections to every other project's CLAUDE.md
3. Never modify shared sections in only one project

The **project-specific sections** (Requirements, QA Plan) belong only to this project and are never copied elsewhere.

Current projects sharing this file:
- `/Users/jonzanoff/Documents/jonzan0ff/Projects/Camp Clintondale/` (also in guest/ and admin/ sub-repos)
- `/Users/jonzanoff/Documents/jonzan0ff/Projects/HomeTeam/`
- `/Users/jonzanoff/Documents/jonzan0ff/Projects/What to watch/`

Any new project created under `/jonzan0ff/` should receive a copy of this file with shared sections intact and fresh project-specific sections.

### User Context

The user prompting is not an engineer or software developer. No technical questions or prompts should be sent their way. Permissioning prompts should only be for installing new software on the local machine or making changes to the system beyond the project folder. Handle everything else autonomously.

---

# ═══════════════════════════════════════════════════════════════════════════════
# SHARED SECTIONS — Identical across all projects
# ═══════════════════════════════════════════════════════════════════════════════

---

# Coding Standards

- Use latest versions of libraries and idiomatic approaches as of today
- Keep it simple — NEVER over-engineer, ALWAYS simplify, NO unnecessary defensive programming
- No extra features — focus on simplicity
- Be concise. Keep README minimal.
- All web projects use TypeScript, no exceptions
- All native Apple projects use Swift, no exceptions
- Emojis: allowed only in AI-generated conversational responses to end users (tasteful). No emojis in app UI, admin UI, or other user-visible strings or assets in code.

---

# QA Master Standards

Standards for AI-assisted development. Apply to every project.

## Philosophy

Three non-negotiable principles:

1. **If a user can see it, the agent must have already seen it.**
2. **If a bug exists, it must be proven before it is fixed.**
3. **Every build must be verified before and after deployment.**

## Agent Owns QA

The AI agent is responsible for quality. Humans review only what cannot be automated.

Agent responsibilities:
- Write tests before or alongside code
- Run tests before every push
- Capture screenshots of all user-facing screens
- Detect regressions
- Block bad builds
- Explicitly confirm build readiness

Human responsibilities:
- UX quality ("does this feel right?")
- Product decisions
- Edge cases that resist automation

## Definition of Done

A build is ready for human review only when:

- All automated tests pass locally
- All automated tests pass in production
- All critical flows executed end-to-end
- Screenshots captured for all key screens
- No unexpected visual regressions
- Logs are clean (no silent failures)
- Agent explicitly confirms readiness

## Test-First, Always

- Write tests before writing features when possible
- At minimum, write tests alongside features in the same commit
- Never ship a feature without test coverage
- Tests are not afterthoughts — they are the proof the feature works

## Regression Testing

Every change gets two test runs:

1. **Before push** — full suite against localhost
2. **After deploy** — full suite against production

If either run has failures, the work is not done.

### After a bug fix

Every fix must include:
- A failing test that reproduces the bug before the fix
- A passing test that proves the fix after
- Visual validation if the bug was UI-related
- A full regression run to confirm nothing else broke

## Visual QA (Non-Negotiable)

Everything user-facing must be visually validated before human review.

### Scope

- All screens
- All states: empty, loading, error, success
- Navigation transitions
- Interactive elements (buttons, forms, toggles)
- Typography and copy
- Icons and images
- Layout spacing and alignment

### Process

For every test run:
1. Navigate to the screen
2. Capture a screenshot
3. Compare to baseline (if baselines exist)
4. Flag any visual anomaly

### Fail conditions

- Layout shift
- Missing elements
- Misalignment
- Incorrect or truncated text
- Unexpected style or color changes
- Components not rendering

### Baselines

- Must be explicitly approved
- Any UI change must update the baseline and call it out in the commit

## Bug Handling (Hard Rule)

**No code changes until the bug is reproduced and verified.**

### Workflow

1. **Reproduce** — follow exact steps; use logs, screenshots, traces
2. **Verify** — capture evidence: screenshot, logs, reproduction steps
3. **Fix** — only after reproduction is confirmed
4. **Protect** — add a regression test that would have caught it
5. **Validate** — full regression suite, both local and production

### If the bug cannot be reproduced

Do not guess. Instead:
1. Add missing test coverage around the area
2. Improve logging
3. Add visual capture
4. Re-run QA
5. Attempt reproduction again

## Regression Rule

When a regression is reported — especially if the user says it was just introduced:

1. Check git log and diff against the last known working state **first**
2. Reproduce the exact failure via the simplest possible method before touching any code
3. Never change unrelated systems to fix a localized problem
4. User temporal signals ("you just broke this") are high-confidence — weight them above your own hypothesis
5. No code changes until the cause is confirmed, not guessed

## Change Impact Rule

Before making any change — code, config, or external service:

1. **Search before changing** — find every reference to what you're modifying across the entire project
2. **Cross-app awareness** — if the system has multiple apps with shared infrastructure, changes in one can break another
3. **External dependencies** — if a change touches auth, URLs, env vars, or third-party config, enumerate every place that references the old value: code, environment variables, and dashboard settings
4. **State the impact** — before committing, list what else is affected and confirm nothing is missed
5. **If removing or renaming something** — confirm zero remaining references first; do not assume the change is isolated

## Post-Deployment Verification

Any time it is technically possible to observe the result after deployment, verify it:

- If there's a URL, hit it
- If there's a UI, screenshot it
- If there's an API, call it
- If there's a database change, query it

Production verification is not optional. If you can see it, check it.

## Dedicated QA Accounts

- Use a dedicated QA test account for all automated tests — never depend on real user data
- The QA account should be auto-provisioned by tests if missing
- Protect the QA account from deletion and editing in admin interfaces
- Tests should clean up after themselves but never delete the QA account itself

## Test Resilience

- Tests must not depend on AI output being deterministic — add fallback paths for non-deterministic responses
- Tests must not depend on exact counts when background processes (timers, triggers) can add records between assertions
- Tests must manage their own state: set up preconditions in beforeAll, restore original state in afterAll
- Tests should not depend on execution order across files — each file must be independently runnable
- Sequential tests within a file are fine when operations build on each other

## Release Flow

1. Agent runs full test suite locally
2. Agent pushes code
3. Deployment triggers automatically (via git push, not CLI tools)
4. Agent runs full test suite against production
5. Agent confirms all green
6. Build is ready for human review

## What This System Does Not Do

- Replace human judgment about UX quality
- Infer user intent without verification
- Fix bugs without reproduction
- Skip production verification because localhost passed
- Assume a change is isolated without checking

## Final QA Standard

Automate everything deterministic. Visually verify everything user-facing. Prove every bug before fixing it. Verify every deployment after shipping it. No exceptions.

---

# Tech Stack

These are the tools and services we have experience with across our projects. Not everything here will be relevant to every project — use what fits. But when you need something in one of these categories, default to what we already know unless there's a strong reason not to.

## Server & Database

- **Supabase** — PostgreSQL database, auth, storage, realtime *(Camp Clintondale, What to Watch)*

## Web Apps

- **Next.js** — React framework, server-side rendering, API routes *(Camp Clintondale, What to Watch)*
- **React** — UI library *(Camp Clintondale)*
- **TypeScript** — All web projects use TypeScript, no exceptions

## Styling

- **Tailwind CSS** — Utility-first CSS *(Camp Clintondale)*
- **shadcn/ui** — Copy-paste component library built on Radix *(Camp Clintondale admin)*
- **Lucide** — Icon library *(Camp Clintondale admin)*

## Forms & Validation

- **React Hook Form** — Form state management *(Camp Clintondale admin)*
- **Zod** — Schema validation *(Camp Clintondale admin, What to Watch API)*

## AI

- **Anthropic Claude API** — LLM for conversational AI, tool use *(Camp Clintondale)*

## Auth

- **Supabase Auth** — Magic link, OTP, email-based auth *(Camp Clintondale)*

## Email

- **Resend** — SMTP provider used by Supabase for transactional email delivery *(Camp Clintondale)*

## Hosting & Deployment

- **Vercel** — Hosting, automatic deploys from git push *(Camp Clintondale, What to Watch)*
- **GitHub** — Source control *(all projects)*
- **GitHub Pages** — Static asset hosting for logos and images *(HomeTeam, What to Watch)*
- **GitHub Releases** — Binary distribution for macOS apps *(What to Watch)*
- **xcodegen** — Generates `.xcodeproj` from a declarative `project.yml` *(HomeTeam, What to Watch)*

## Mac / iOS Apps

- **Swift (latest)** — Language for all native Apple targets *(HomeTeam, What to Watch)*
- **SwiftUI** — Declarative UI framework for menu bar popover and widget *(HomeTeam, What to Watch)*
- **AppKit** — Menu bar integration (NSStatusItem, NSPopover, NSMenu) *(HomeTeam, What to Watch)*
- **WidgetKit** — macOS widget extension *(HomeTeam, What to Watch)*
- **App Groups** — Shared container for data between app and widget *(HomeTeam, What to Watch)*

## External APIs

- **ESPN API** — Schedule, scores, and streaming data for NHL, NFL, MLB, NBA, MLS, Premier League, F1 *(HomeTeam)*
- **MotoGP Calendar API** — Race schedule for MotoGP *(HomeTeam)*
- **TMDB API** — TV show/movie search, episode data, watch providers *(What to Watch)*

## QA & Testing

### Test Runners

- **XCTest** — Unit tests, no network, deterministic *(HomeTeam, What to Watch)*
- **XCUITest** — UI tests, real app process, accessibility-driven *(HomeTeam, What to Watch)*
- **Playwright** — End-to-end API and browser testing *(Camp Clintondale, What to Watch)*

### Visual Regression

- **NSHostingView → bitmapImageRepForCachingDisplay → PNG** — Zero-dependency widget snapshot rendering pipeline *(HomeTeam, What to Watch)*
- **Snapshot baselines** — Reference PNGs committed to `Tests/__Snapshots__/`, compared on every test run
- **screencapture** — macOS CLI tool for capturing app windows during development QA

### CI/CD

- **GitHub Actions** — All CI runs on `macos-14` (Swift) or `ubuntu-latest` (Playwright)
- **Workflows per project:**
  - `unit-gate.yml` — PR gate, unit tests
  - `ui-qa.yml` — PR gate, widget/app snapshot tests
  - `api-tests.yml` — API route tests + post-deploy production verification
  - `qa-regression-telemetry.yml` — Weekly regression suite with telemetry persistence

### Telemetry & History

- **xcresulttool** — Extracts pass/fail/skip metrics from `.xcresult` bundles
- **qa-history branch** — Timestamped telemetry JSON appended via `persist_test_history.sh`
- **Artifact uploads** — xcresult bundles, snapshot diffs, and telemetry uploaded as CI artifacts

### QA Scripts

- **qa_unit_gate.sh** — Layer 1: xcodebuild unit tests (no signing)
- **capture_widget_screenshot.sh** — Layer 2: Widget snapshot tests (coverage/record modes)
- **qa_frontend_ui.sh** — Layer 2: Frontend snapshot tests
- **qa_ui_tests.sh** — Layer 3: XCUITest (requires signing, workflow_dispatch only)
- **collect_test_telemetry.sh** — Extract metrics from xcresult bundles
- **persist_test_history.sh** — Append telemetry to qa-history branch

### QA Principles (from QA Master Standards)

1. If a user can see it, the agent must have already seen it
2. If a bug exists, it must be proven before it is fixed
3. Every build must be verified before and after deployment
4. Tests written alongside code, never after
5. Visual regression on every UI change
6. Production verification is not optional

---

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT-SPECIFIC SECTIONS — Unique to HomeTeam
# ═══════════════════════════════════════════════════════════════════════════════

---

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

---

# QA Plan: HomeTeam

> Implements the strategy defined in the QA Master Standards. This file contains HomeTeam-specific test layers, fixtures, and engineering rules.

> Goal: eliminate UAT guesswork. Every behavior that can be asserted in code should be. Manual UAT
> should only cover what automation structurally cannot reach (visual pixel-polish, system UI surfaces).

---

## Layer 0 — App Group smoke test (separate project)

> A throwaway two-target Xcode project (`AppGroupSmokeTest`) proving the App Group plumbing works.
> Once it passes it can be archived. Not part of the main test suite.

| Test | Asserts |
|---|---|
| `testAppGroupContainerURLIsNonNil` | `containerURL(forSecurityApplicationGroupIdentifier:)` returns non-nil |
| `testAppGroupContainerIsWritable` | Write + read back from container succeeds |
| `testAppGroupRoundTripJSON` | Encode → write → decode round-trip produces identical values |
| `testAppGroupWriteFromOneTargetReadFromAnother` | File written by SmokeApp is readable from test runner |

---

## The hard limit: widget OS integration cannot be automated

| Action | Why |
|---|---|
| Add widget from macOS gallery | `notificationcenterui` is a separate OS process |
| Widget configuration sheet | OS-rendered, not app-rendered |
| Team picker selection | Same OS process restriction |
| Widget re-renders after change | WidgetKit timeline is OS-scheduled |

Strategy: make every layer **below** the OS surface airtight so manual UAT is minimal.

---

## Test pyramid

```
         ┌──────────────────────────────┐
         │   UAT (human)                │  ← pixel polish, OS widget picker UX
         ├──────────────────────────────┤
         │   UI Tests (XCUITest)        │  ← app navigation, onboarding,
         │                              │     App Group JSON correctness
         ├──────────────────────────────┤
         │   Snapshot / Preview Tests   │  ← widget view with fixture data
         ├──────────────────────────────┤
         │   Unit Tests (no network)    │  ← all business logic
         └──────────────────────────────┘
```

---

## Layer 1 — Unit tests (no network, no UI, instant)

Run via `xcodebuild test -only-testing HomeTeamTests`.

### 1A. Widget game filtering

The widget timeline provider (`makeEntry`) splits games into live/previous/upcoming. These
filtering rules are extracted into `WidgetGameFilter` for testability.

| Test | Input | Expected |
|---|---|---|
| `live_includesLiveGames` | game with `.live` status | included in live |
| `live_excludesFinalGames` | game with `.final` status | excluded from live |
| `live_excludesScheduledGames` | game with `.scheduled` status | excluded from live |
| `previous_includesFinalBeforeNow` | final game, `scheduledAt` in past | included |
| `previous_excludesFinalAfterNow` | final game, `scheduledAt` in future | excluded |
| `previous_excludesLiveGames` | live game | excluded |
| `previous_sortedNewestFirst` | 5 finals at different dates | most recent first |
| `previous_limitedTo3` | 10 final games | only 3 returned |
| `upcoming_includesScheduledAfterNow` | scheduled game in future | included |
| `upcoming_excludesScheduledBeforeNow` | scheduled game in past | excluded |
| `upcoming_excludesFinalGames` | final game in future | excluded |
| `upcoming_sortedEarliestFirst` | 5 scheduled games | chronological order |
| `upcoming_limitedTo3` | 10 scheduled games | only 3 returned |
| `racing_matchesBySport` | F1 game, team with `sport == .f1` | included |
| `racing_doesNotMatchByTeamID` | F1 game, team with different sport | excluded |
| `teamSport_matchesByHomeTeamID` | NHL game, team with matching `espnTeamID` | included |
| `teamSport_matchesByAwayTeamID` | NHL game, team with matching `espnTeamID` as away | included |
| `teamSport_excludesNonMatchingTeamID` | NHL game, wrong team | excluded |
| `streamingFilter_passesAll_whenNoSelection` | no streaming keys, any game | included |
| `streamingFilter_passesMatching` | `["espnplus"]`, game on ESPN+ | included |
| `streamingFilter_hidesNonMatching` | `["espnplus"]`, game on Peacock | excluded |
| `isOffSeason_true_whenNoUpcomingAndNotRacing` | NHL, no upcoming games | `isOffSeason = true` |
| `isOffSeason_false_forRacingSports` | F1, no upcoming games | `isOffSeason = false` |

### 1B. Streaming service matching

Tests for `StreamingServiceMatcher.canonicalKey(for:)` and `isMatch(rawName:selectedKeys:)`.

| Test | Input | Expected |
|---|---|---|
| `canonicalKey_espnPlus` | `"ESPN+"` | `"espnplus"` |
| `canonicalKey_appleTV` | `"Apple TV+"` | `"appletvplus"` |
| `canonicalKey_appleTV_withoutPlus` | `"Apple TV"` | `"appletvplus"` |
| `canonicalKey_primevideo` | `"Amazon Prime Video"` | `"primevideo"` |
| `canonicalKey_fs1_variants` | `"FS1"`, `"Fox Sports 1"` | `"fs1"` |
| `canonicalKey_fs2_variants` | `"FS2"`, `"Fox Sports 2"` | `"fs2"` |
| `canonicalKey_fox` | `"Fox"` | `"fox"` |
| `canonicalKey_max_catchesTNT` | `"TNT"` | `"max"` |
| `canonicalKey_max_catchesHBO` | `"HBO"`, `"HBO Max"` | `"max"` |
| `canonicalKey_max_catchesTNTSlashHBO` | `"TNT/HBO"` | `"max"` |
| `canonicalKey_max_catchesTruTV` | `"TruTV"`, `"truTV"`, `"TrueTV"` | `"max"` |
| `canonicalKey_unknown_returnsNil` | `"FakeNetwork123"` | `nil` |
| `isMatch_returnsTrue_whenKeyInSet` | `"ESPN+"` with `["espnplus"]` | `true` |
| `isMatch_returnsFalse_whenKeyNotInSet` | `"Peacock"` with `["espnplus"]` | `false` |
| `isMatch_returnsFalse_whenNoServicesSelected` | `"ESPN+"` with `[]` | `false` |
| `isMatch_max_selected_catchesTNTSlashHBO` | `"TNT/HBO"` with `["max"]` | `true` |

### 1C. Race name formatting

Tests for `GameFormatters.compactRaceName(from:)`.

| Input | Expected |
|---|---|
| `"Australian Grand Prix"` | `"Australian GP"` |
| `"Qatar Airways Australian Grand Prix"` | `"Australian GP"` |
| `"Formula 1 Bahrain Grand Prix 2024"` | `"Bahrain GP"` |
| `"Grand Prix of Monaco"` | `"Monaco GP"` |
| `"Heineken Dutch Grand Prix"` | `"Dutch GP"` |
| `"MotoGP Grand Prix of Spain"` | `"Spain GP"` |
| `"GP of Monaco"` | `"Monaco GP"` |
| `"MotoGP GP of Spain"` | `"Spain GP"` |
| `"Qatar Airways Australian GP"` | `"Australian GP"` |
| `"Sao Paulo GP"` | `"Sao Paulo GP"` (unchanged, 3-word) |
| `"United States Grand Prix"` | `"Americas GP"` (hard-coded override) |
| `""` | `""` |

### 1D. Live status compact label

Tests for `GameFormatters.compactLiveStatus(from:)`.

| Input | Expected |
|---|---|
| `nil` | `"LIVE"` |
| `""` | `"LIVE"` |
| `"3rd Period - 14:32"` | `"3RD • 14:32"` |
| `"End of the 2nd Period Intermission"` | `"2ND INT"` |
| `"Intermission"` | `"INT"` |
| `"Overtime"` | `"OT"` |
| `"Shootout"` | `"SO"` |

### 1E. Race points

Tests for `GameFormatters.racePoints(for:sport:)`.

| Position | Sport | Expected |
|---|---|---|
| 1 | `.motoGP` | `25` |
| 1 | `.f1` | `25` |
| 2 | `.f1` | `18` |
| 10 | `.f1` | `1` |
| 11 | `.f1` | `nil` (outside points) |
| 0 | `.motoGP` | `nil` (DNF) |
| 5 | `.nhl` | `nil` (non-racing) |

### 1F. Race flag lookup

Tests for `GameFormatters.raceFlag(for:)`.

| Input | Expected |
|---|---|
| `"Japanese Grand Prix"` | `"🇯🇵"` |
| `"Americas GP"` | `"🇺🇸"` |
| `"Thailand GP"` | `"🇹🇭"` |
| `"Unknown Location GP"` | `nil` |

### 1G. ScheduleSnapshot merge (non-destructive)

Tests for `ScheduleSnapshot.mergingNondestructively(with:)`.

| Scenario | Expected |
|---|---|
| New snapshot has games | use new games |
| New snapshot empty, existing has games | keep existing games |
| New snapshot has games, existing has games | use new games |
| New snapshot empty, existing empty | empty |
| New has summaries, existing has summaries | use new summaries |
| New has empty summaries, existing has summaries | keep existing summaries |

### 1H. App settings persistence

Tests for `AppGroupStore.write/read` with `AppSettings`.

| Test | Asserts |
|---|---|
| `roundTrip_default` | Encode + decode `.default` → identical |
| `roundTrip_withFavoritesAndStreaming` | Populated settings survive round-trip |
| `roundTrip_preservesNotificationSettings` | Nested `AppNotificationSettings` intact |
| `decoding_missingFieldsFallsBackToDefaults` | Old JSON without new fields decodes gracefully |

### 1I. MotoGP calendar parser

Tests for `MotoGPCalendarParser.parse(_:)` and `circuitTimezones(from:)`.

| Test | Asserts | Status |
|---|---|---|
| `usesDateEnd_asRaceDay` | `scheduledAt` weekday = Sunday (from `date_end`) | done |
| `fallsBackToDateStart_whenNoDateEnd` | Uses `date_start` when `date_end` is nil | done |
| `hardcodesFS1_broadcast` | `broadcastNetworks == ["FS1"]` | done |
| `fs1_matchesStreamingFilter` | FS1 broadcast passes `["fs1"]` streaming filter | done |
| `grandPrix_shortenedToGP` | `homeTeamName` contains "GP", not "Grand Prix" | done |
| `sponsoredName_fallback` | Sponsored name also normalized to GP | done |
| `filtersOutTestEvents` | `test: true` events produce 0 games | done |
| `includesNonTestEvents` | `test: false` events produce 1 game | done |
| `status_finished_mapsFinal` | `"FINISHED"` → `.final` | done |
| `status_inProgress_mapsLive` | `"IN-PROGRESS"` → `.live` | done |
| `status_started_mapsScheduled` | `"STARTED"` → `.scheduled` | **not impl** |
| `status_nil_futureDate_mapsScheduled` | nil status, future date → `.scheduled` | done |
| `status_nil_pastDate_mapsFinal` | nil status, past date → `.final` | done |
| `status_unknown_pastDate_mapsFinal` | `"CLOSED"`/`"COMPLETED"`/`"ENDED"` all → `.final` | done |
| `status_closed_futureDate_mapsScheduled` | unknown status + future date → `.scheduled` | done |
| `circuitTimezone_COTA_isChicago` | legacy_id 101 → `America/Chicago` | done |
| `circuitTimezone_Silverstone_isLondon` | legacy_id 42 → `Europe/London` | done |
| `circuitTimezone_Motegi_isTokyo` | legacy_id 76 → `Asia/Tokyo` | done |
| `circuitTimezone_PhillipIsland_isMelbourne` | legacy_id 32 → `Australia/Melbourne` | done |
| `circuitTimezone_Sepang_isKualaLumpur` | legacy_id 75 → `Asia/Kuala_Lumpur` | done |
| `circuitTimezone_unknownID_returnsEmpty` | legacy_id 999 → not in map | done |

### 1J. ESPN racing parser

Tests for `ESPNRacingParser.parse(_:sport:)`.

| Test | Asserts |
|---|---|
| `usesTypeId3_asRaceCompetition` | Race date from competition with `type_id: 3` |
| `fallsBackToLastCompetition_whenNoTypeId3` | Uses last competition as fallback |
| `extractsBroadcastNames_fromNamesArray` | Broadcast names from `names` array |
| `broadcastNames_emptyWhenNoBroadcasts` | Empty array when no broadcasts |
| `appleTV_matchesStreamingFilter` | `"Apple TV"` → `appletvplus` key |
| `homeTeamName_storedVerbatim` | Raw name preserved; `compactRaceName` strips sponsor at display time |
| `sponsorPlusLocation_compactsToLocationGP` | `"Crypto.com Miami Grand Prix"` → `"Miami GP"` via `compactRaceName` |
| `nonGrandPrixName_unchanged` | Non-GP names stored verbatim |
| `status_pre_mapsScheduled` | `"pre"` → `.scheduled` |
| `status_in_mapsLive` | `"in"` → `.live` |
| `status_post_completed_mapsFinal` | `"post"` + `completed: true` → `.final` |
| `sport_passedThrough` | Sport parameter flows through to game |

### 1K. Menu bar game filter

Tests for `menuBarGames(from:selectedStreamingKeys:hiddenCompositeIDs:)`.

| Test | Asserts |
|---|---|
| `excludesFinalGames` | Final games not in result |
| `excludesPostponedGames` | Postponed games not in result |
| `sortedByScheduledAt` | Ascending by `scheduledAt` |
| `noStreamingSelection_showsAll` | Empty keys → all games pass |
| `streamingFilter_showsMatchingGame` | Matching game included |
| `streamingFilter_hidesNonMatchingGame` | Non-matching game excluded |
| `streamingFilter_hidesUnrecognisedNetworks` | Unknown network excluded when filter active |

### 1L. App Group store

Tests for `AppGroupStore` container access and file operations.

| Test | Asserts |
|---|---|
| `containerURL_isNonNil` | App Group container accessible (skip in unsigned CI) |
| `roundTrip_appSettings` | Write + read `AppSettings` produces identical result |
| `logoFileURL_emptyEspnTeamID_alwaysNil` | Empty ID → `nil` for any sport |
| `logoFileURL_motoGP_nonexistentID_isNil` | Non-existent file → `nil` |

### 1M. Team catalog integrity

| Test | Asserts |
|---|---|
| `nhl_washingtonCapitals_espnTeamID` | ESPN ID = `"23"` |
| `nhl_seattleKraken_espnTeamID` | ESPN ID = `"124292"` |
| `nhl_espnTeamIDs_areUnique` | No duplicate ESPN IDs within NHL |
| `f1_allEntries_haveNonEmptyEspnTeamID` | No empty `espnTeamID` in F1 catalog |
| `f1_kickSauber_isInCatalog` | 2 driver entries for Kick Sauber |
| `f1_raceLabel_includesDriver` | `raceLabel` contains driver name + constructor |
| `motoGP_ducati_displayName_isJustDucati` | No "Lenovo" in display name |
| `motoGP_allEntries_haveDriverDisplayName` | No nil/empty `driverDisplayName` |

### 1N. HomeTeamTeamSummary formatting

Tests for `inlineDisplay` and `shortenPlace`.

| Test | Asserts |
|---|---|
| `shortenPlace_NFC` | `"National Football Conference"` → `"NFC"` |
| `shortenPlace_AFC` | `"American Football Conference"` → `"AFC"` |
| `shortenPlace_metropolitanDivision` | → `"Metro Div."` |
| `shortenPlace_nationalLeague` | → `"NL"` |
| `shortenPlace_unknownDivision_passesThrough` | Unrecognized text unchanged |
| `inlineDisplay_standard_format` | Contains record, L10, streak, shortened place |
| `inlineDisplay_hides_l10_when_missing` | `"-"` → no "L10" in output |
| `inlineDisplay_hides_streak_when_missing` | `"-"` → no trailing dash |
| `inlineDisplay_racing_format` | Contains Place, Pts, Wins, Podiums |

### 1O. HomeTeamGame patching

Tests for `patchingRacingResults`, `patchingScheduledAt`, `patching(homeScore:...)`.

| Test | Asserts |
|---|---|
| `patchingRacingResults_attachesResults` | Results present on returned copy |
| `patchingRacingResults_preservesOtherFields` | All other fields unchanged |
| `patchingScheduledAt_updatesDate` | `scheduledAt` changed to new date |
| `patchingScheduledAt_preservesOtherFields` | All other fields unchanged |
| `patching_updatesScoresAndDetail` | Scores and statusDetail changed |

---

## Layer 2 — Snapshot tests (no network, visual regression)

Dependency-free: renders `HomeTeamWidgetEntryView` via `NSHostingView` →
`bitmapImageRepForCachingDisplay` → PNG. No external packages needed.

Reference PNGs committed to `Tests/__Snapshots__/`. Toggle `recordMode` in
`WidgetSnapshotTests.swift` to re-record after intentional visual changes.

### 2A. Fixture scenarios (all implemented)

| Fixture | Sport | Previous | Upcoming | Notes |
|---|---|---|---|---|
| `nhl_typical` | NHL | 3 finals with scores | 2 scheduled with streaming badges | Standard case |
| `nhl_live_game` | NHL | 1 final | 1 live (2ND - 8:42) + 1 scheduled | Live chip + score |
| `nhl_offseason` | NHL | 1 final | empty | Off-season zzz message |
| `f1_typical` | F1 | 2 GP finals with P1-P3 results | 3 GP scheduled with TV+ | Race results |
| `motogp_typical` | MotoGP | 2 GP finals (DNF + P4) | 3 GP scheduled with FS1 | Abbreviated names |
| `unconfigured` | -- | -- | -- | "No team selected" placeholder |
| `no_games` | NHL | empty | empty | "No games available" |

### 2B. How it works

```swift
// Render widget view to PNG — no external dependencies
let view = HomeTeamWidgetEntryView(entry: entry)
    .frame(width: 329, height: 345)
    .environment(\.colorScheme, .light)
let hostingView = NSHostingView(rootView: view)
hostingView.frame = NSRect(origin: .zero, size: widgetSize)
hostingView.layoutSubtreeIfNeeded()
let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
let pngData = bitmapRep.representation(using: .png, properties: [:])!
// Compare pngData against committed reference PNG
```

---

## Layer 3 — UI tests (XCUITest, real app process)

> **Status: Not implemented.** High maintenance cost, low bug-catch rate for this project's
> change patterns. Build these when a bug ships that only a UI test would have caught.
>
> **Trigger to build:** If a bug is found where settings/favorites were lost across relaunch,
> or onboarding broke silently, add the specific UI test that would have caught it and
> note the incident below.
>
> **Incidents that would have justified Layer 3:**
> *(none yet)*

### 3A. Onboarding flows
- Onboarding shown after reset
- Quick links route to correct Settings sections
- Onboarding dismisses after favorite + streaming + refresh

### 3B. App Group container correctness

| Test | What it checks |
|---|---|
| App Group container URL available | Entitlements configured correctly |
| `app_settings.json` written after onboarding | File exists and is valid JSON |
| `favoriteTeamCompositeIDs` non-empty after adding a favorite | Widget picker will show teams |
| `schedule_snapshot.json` written after refresh | Widget can render data |
| `selectedStreamingServices` persists across app relaunch | Widget inherits filter |

### 3C. Settings persistence

| Test | Verifies |
|---|---|
| Add favorite → relaunch → favorite still listed | Favorites survive relaunch |
| Reorder favorites → relaunch → order preserved | Order survives relaunch |
| Remove favorite → relaunch → gone | Removal survives relaunch |
| Toggle streaming service → relaunch → still toggled | Streaming survives relaunch |

---

## Layer 4 — Network smoke tests (opt-in, CI nightly)

> **Status: Not implemented.** Valuable for catching API schema drift and endpoint
> deprecation, but only useful when running on a schedule (nightly CI). Build these
> when CI infrastructure is set up, or when an API change breaks the app silently.
>
> **Trigger to build:** If an API returns empty/changed data and the app silently shows
> stale or missing content (e.g. ESPN MotoGP standings returning empty `children`,
> Pulselive session endpoint changing schema), add the specific smoke test and note
> the incident below.
>
> **Incidents that would have justified Layer 4:**
> - *2026-03-26: ESPN MotoGP standings endpoint returns empty `children` array — had to
>   switch to Pulselive standings API. A smoke test asserting `children.count >= 1` would
>   have flagged this before the widget showed missing stats.*

Run with `HOMETEAM_RUN_NETWORK_TESTS=1`.

| Test | Checks |
|---|---|
| ESPN NHL schedule returns ≥1 game | API contract stable |
| ESPN F1 schedule returns ≥1 event | API contract stable |
| MotoGP PulseLive returns ≥1 event | API contract stable |
| MotoGP PulseLive sessions returns ≥1 session | Session timestamp API stable |
| NHL standings returns record strings | Standings API stable |
| MotoGP standings returns position + points | Pulselive standings API stable |
| Decoding succeeds without throwing | No schema drift |

---

## What NOT to automate (leave for UAT)

| Item | Why |
|---|---|
| Add widget from gallery | OS process |
| Widget configuration sheet | OS-rendered |
| Team picker selection | OS-rendered |
| Edit widget (right-click) | OS-rendered |
| Widget re-renders after change | OS-scheduled |
| Logo image quality | Human eye |
| "Open at Login" behavior | `SMAppService`, unreliable in tests |

---

## UAT checklist — minimum per handoff

### App
- [ ] Launch fresh → onboarding appears
- [ ] Add favorite team → checklist row turns green
- [ ] Add streaming service → checklist row turns green
- [ ] Onboarding dismisses after both steps
- [ ] Main scoreboard shows Previous + Upcoming
- [ ] Live game card has red border
- [ ] Drag-reorder favorites → order persists after relaunch
- [ ] Toggle streaming → upcoming updates immediately

### Widget
- [ ] Add from gallery → config sheet appears (not blank)
- [ ] Config sheet shows favorite teams at top
- [ ] Select team → widget renders with data
- [ ] Previous shows real results
- [ ] Upcoming shows real games with correct times
- [ ] Right-click → Edit → change team → updates
- [ ] F1/MotoGP shows race names, driver results, favorite highlighted
- [ ] Logos crisp on dark background

---

## CI pipeline

```
PR gate (every commit):
  1. xcodebuild test -only-testing HomeTeamTests    ← all unit tests
  2. HomeTeamUITests                                 ← app + App Group correctness

Nightly:
  3. Network smoke tests (HOMETEAM_RUN_NETWORK_TESTS=1)
  4. Snapshot tests (swift-snapshot-testing)

Pre-release:
  5. Full UAT checklist (human, ~5 min)
```

---

## Engineering rules (QA-driven)

1. **One normalization path** — all streaming names through `StreamingServiceMatcher.canonicalKey()`.
2. **Injectable `now: Date`** — all date-sensitive filtering accepts `now` as a parameter.
3. **Widget view is pure** — `HomeTeamWidgetEntryView` takes only `HomeTeamEntry`, no stores.
4. **App Group writes are synchronous** — `AppGroupStore.write()` throws on failure.
5. **Accessibility identifiers are a contract** — don't rename without updating UI tests.
6. **Racing uses sport-level matching** — `sport == team.sport`, not `homeTeamID` matching.
7. **Circuit timezones are explicit** — Pulselive session timestamps are circuit-local; `MotoGPCalendarParser.circuitTimezones` maps legacy_id → IANA timezone.
