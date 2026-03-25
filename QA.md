# HomeTeam — QA Strategy

> Goal: eliminate UAT guesswork. Every behavior that can be asserted in code should be. Manual UAT
> should only cover what automation structurally cannot reach (visual pixel-polish, system UI surfaces).

---

## Layer 0 — App Group smoke test (run before writing any HomeTeam code)

> **Why this exists**: the old app's entitlements files were empty — meaning the widget and app were almost certainly writing to separate sandboxed containers, not the shared App Group. This is likely the root cause of the widget QA failures. We verify the plumbing works before building anything on top of it.
>
> This is a **throwaway two-target Xcode project** (`AppGroupSmokeTest`). It has no product value. Its only job is to prove that the Apple Developer account, Xcode signing, and the App Group identifier `group.com.jonzanoff.hometeam` all work together on this machine. Once it passes it can be deleted or archived.

### What to build

A minimal Xcode project with **two targets** and **one test target**, all sharing the same App Group:

**Target 1 — `SmokeApp`** (macOS App)
- On launch: writes `{"source": "app", "timestamp": "<ISO date>"}` to `<AppGroupContainer>/smoke_test.json`
- Displays the write result on screen (success or error message)
- Entitlement: `com.apple.security.application-groups` = `["group.com.jonzanoff.hometeam"]`

**Target 2 — `SmokeWidget`** (WidgetKit extension)
- Timeline provider reads `smoke_test.json` from the same App Group container
- Widget displays the `source` and `timestamp` values, or "No data yet" if the file is absent
- Entitlement: same App Group as above

**Target 3 — `SmokeTests`** (XCTest, also has the App Group entitlement)

The tests I can run with `xcodebuild test`:

```
testAppGroupContainerURLIsNonNil
  → FileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jonzanoff.hometeam") != nil
  → FAILS if the group is not registered in the Apple Developer portal or entitlements are wrong

testAppGroupContainerIsWritable
  → Write a known string to <container>/smoke_rw_test.txt
  → Read it back, assert content matches
  → FAILS if the container exists but permissions are wrong

testAppGroupRoundTripJSON
  → Encode {"ping": true, "value": 42} → write to <container>/smoke_json.json
  → Decode from same path → assert decoded values match
  → FAILS if JSON serialization or file I/O through the container is broken

testAppGroupWriteFromOneTargetReadFromAnother
  → This is the cross-process proof: SmokeApp writes the file at launch (UAT step)
  → This test reads that same file from the test runner process (which also has the entitlement)
  → Assert the file exists and contains `"source": "app"`
  → FAILS if the app and test runner are not sharing the same container
```

### Pass criteria (I can verify all of these)

```
xcodebuild test \
  -project AppGroupSmokeTest.xcodeproj \
  -scheme SmokeTests \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM=<your team ID>
```

All 4 tests green = App Group is correctly provisioned, entitlements are set, and cross-process file sharing works.

### What the human needs to verify (UAT, 2 minutes)

1. Build and run `SmokeApp` — confirm it shows "Write succeeded"
2. Add `SmokeWidget` to the macOS desktop
3. Confirm the widget shows the timestamp written by the app (not "No data yet")

If the widget shows "No data yet" after the app has launched, the App Group is not shared between the two processes despite the tests passing — which would indicate a signing/provisioning mismatch that needs fixing before HomeTeam development begins.

### Why not just use the HomeTeam entitlements directly

Because debugging App Group issues inside a complex app (with real data fetching, settings, widget configuration) is hard. The smoke test isolates the one variable — shared container file I/O — with zero noise. Fix the plumbing at minimum complexity, then build on it.

---

## The hard limit: widget OS integration cannot be automated

The following widget behaviors **cannot be automated by any test tooling** — they are UAT-only:

| Action | Why it cannot be automated |
|---|---|
| Add widget from macOS gallery | `com.apple.notificationcenterui` is a separate OS process; XCUITest cannot drive it without system accessibility grants that CI machines do not have |
| Widget configuration sheet appears on add | The sheet is OS-rendered, not app-rendered |
| Select a team in the widget picker | Same OS process restriction |
| Edit widget (right-click → Edit "HomeTeam") | Same |
| Widget re-renders after team change | WidgetKit timeline delivery is OS-scheduled; no force-refresh API |

The previous `desktop_automation_gate.sh` attempted to bridge this via AppleScript/Accessibility APIs. It was fragile, required a real signed build, required a real Mac with accessibility permissions granted, and was not CI-safe. **Do not attempt to automate these steps in the rebuild.**

The strategy is: make every layer *below* the OS surface airtight with automation, so the manual UAT checklist is as short as possible.

### Widget QA coverage map

| What you're checking | How it's covered |
|---|---|
| Widget view renders correctly | Snapshot tests with fixture data |
| Filtering / formatting logic | Unit tests |
| App Group JSON has valid favorites | Shared container UI tests |
| Timeline entry builds correctly | Unit tests on `HomeTeamWidgetContentState` |
| Widget picks correct team after add | **UAT only** |
| Widget picker shows teams (not empty) | **UAT only** (JSON correctness is unit-tested; picker rendering is not) |
| Widget re-renders after settings change | **UAT only** |

---

## The core problem with widget QA (remaining automation challenges)

Widgets are the hardest surface to automate on macOS because:

1. **The widget process is isolated.** It has no XPC connection to the app during a test run.
2. **WidgetKit timeline delivery is OS-controlled.** You cannot force a refresh in XCUITest.
3. **The widget picker reads from an App Group JSON file.** If that file is wrong/missing, the picker shows nothing — and you only discover this at UAT.
4. **Widget rendering is a WidgetKit view.** You cannot interact with it via accessibility.

The solution is **to test layers, not the rendered widget directly**.

---

## Test pyramid for HomeTeam

```
         ┌──────────────────────────────┐
         │   UAT (human)                │  ← pixel polish, OS widget picker UX
         ├──────────────────────────────┤
         │   UI Tests (XCUITest)        │  ← app navigation, onboarding flow,
         │                              │     App Group JSON correctness
         ├──────────────────────────────┤
         │   Snapshot / Preview Tests   │  ← widget view rendered with fixture data
         ├──────────────────────────────┤
         │   Unit Tests (no network)    │  ← all business logic, filtering, formatting
         └──────────────────────────────┘
```

The widget's **visual output** is tested at the Snapshot layer with known fixture data.
The widget's **data correctness** is tested at the Unit layer.
The App Group **plumbing** is tested at the UI Test layer.

---

## Layer 1 — Unit tests (no network, no UI, instant)

These must all pass before any handoff. Run via `qa_unit_gate.sh`.

### 1A. Game filtering

Test `Array<HomeTeamGame>` extension methods with fixture arrays.

| Test | Input | Expected |
|---|---|---|
| `nextWidgetGames` includes live game from yesterday | live game with yesterday's start | included |
| `nextWidgetGames` excludes final from yesterday | final game | excluded |
| `nextWidgetGames` includes scheduled from start-of-today | startTimeUTC = midnight today | included |
| `nextWidgetGames` returns max 3 | 10 upcoming games | 3 |
| `upcomingGames` excludes MotoGP practice | session name "Free Practice 1" | excluded |
| `upcomingGames` excludes MotoGP qualifying | session name "Qualifying" | excluded |
| `upcomingGames` excludes MotoGP warm-up | session name "Warm Up" | excluded |
| `upcomingGames` includes MotoGP sprint | session name "Sprint" | included |
| `upcomingGames` includes MotoGP grand prix | session name "Spanish Grand Prix" | included |
| `upcomingGames` includes MotoGP main race | session name "Race" | included |
| `upcomingGames` passes all F1 sessions | session name "Free Practice 1", sport .f1 | included |
| `previousGames` excludes live games | live game from yesterday | excluded |
| `previousGames` excludes future finals | final game in future (edge case) | excluded |
| `previousGames` returns most recent first | 5 finals | newest first |
| `previousGames` limits to racing season year | 2024 races + 2025 upcoming | 2025 only |

### 1B. Streaming filter

| Test | Selected services | Game services | Expected |
|---|---|---|---|
| No selection → pass | `[]` | `["Regional Sports Network"]` | pass |
| No selection → pass even unknown | `[]` | `["Foobar TV"]` | pass |
| Selection → ESPN game passes | `["espn+"]` | `["ESPN+"]` | pass |
| Selection → non-matching fails | `["hulu"]` | `["ESPN+"]` | fail |
| Selection → unknown service fails | `["apple tv"]` | `["Regional Sports Network"]` | fail |
| Hulu TV vs Hulu normalization | `["hulu tv"]` | `["Hulu + Live TV"]` | pass |
| Hulu TV vs Hulu normalization | `["hulu"]` | `["Hulu + Live TV"]` | fail (Hulu TV ≠ Hulu) |
| HBO catches TNT | `["hbo"]` | `["TNT"]` | pass |
| HBO catches Bleacher Report | `["hbo"]` | `["Bleacher Report"] ` | pass |
| Amazon catches Prime Video | `["amazon"]` | `["Prime Video"]` | pass |
| Multiple services — first match wins | `["hulu"]` | `["ESPN+", "Hulu"]` | pass |

### 1C. Streaming service normalization

`AppSettings.normalizedServiceName(rawValue)` unit tests:

| Input | Expected canonical |
|---|---|
| `"ESPN+"` | `"espn+"` |
| `"ESPN Plus"` | `"espn+"` |
| `"Hulu + Live TV"` | `"hulu tv"` |
| `"Hulu Live TV"` | `"hulu tv"` |
| `"Hulu"` | `"hulu"` |
| `"Paramount+"` | `"paramount"` |
| `"Amazon Prime Video"` | `"amazon"` |
| `"Prime Video"` | `"amazon"` |
| `"Apple TV+"` | `"apple tv"` |
| `"AppleTV+"` | `"apple tv"` |
| `"YouTube TV"` | `"youtube tv"` |
| `"TNT"` | `"hbo"` |
| `"TBS"` | `"hbo"` |
| `"TruTV"` | `"hbo"` |
| `"Bleacher Report"` | `"hbo"` |
| `"Max"` | `"hbo"` |
| `"Netflix"` | `"netflix"` |
| `"Regional Sports Network"` | `"regional sports network"` (passthrough) |

### 1D. Race name formatting

`compactRaceName(from:)` unit tests:

| Input | Expected |
|---|---|
| `"Australian Grand Prix"` | `"Australian GP"` |
| `"Qatar Airways Australian Grand Prix"` | `"Australian GP"` |
| `"Formula 1 Bahrain Grand Prix 2024"` | `"Bahrain GP"` |
| `"Grand Prix of Monaco"` | `"Monaco GP"` |
| `"Heineken Dutch Grand Prix"` | `"Dutch GP"` |
| `"MotoGP Grand Prix of Spain"` | `"Spain GP"` |
| `"São Paulo GP"` | `"São Paulo GP"` |
| `""` | `""` |

### 1E. Live status compact label

`compactLiveStatus(from:)` unit tests:

| Input | Expected |
|---|---|
| `""` | `"LIVE"` |
| `"End of the 2nd Period Intermission"` | `"2ND INT"` |
| `"3rd Period - 14:32"` | `"3RD • 14:32"` |
| `"Shootout"` | `"SO"` |
| `"Overtime"` | `"OT"` |
| `"Intermission"` | `"INT"` |

### 1F. Widget content state

Test `HomeTeamWidgetContentState` with fixture `ScheduleSnapshot` and `AppSettings`:

| Scenario | Expected `widgetEmptyStateMessage` title |
|---|---|
| Team not configured, no favorites | "Add favorites in HomeTeam" |
| Team not configured, favorites exist | "Widget not configured" |
| API error message present | "Unable to load games" |
| Upcoming hidden by streaming filter | "Upcoming hidden by streaming filters" |
| Games exist but none qualify | "Schedule is still catching up" |
| Truly empty (no games at all) | "No games available" |

Test `upcomingHiddenByStreamingFilter`:
- True when: unfiltered upcoming non-empty AND filtered upcoming empty
- False when: no services selected
- False when: not configured

### 1G. ScheduleSnapshot merge (non-destructive)

| Scenario | Expected result |
|---|---|
| New snapshot has games → use new | new games |
| New snapshot empty, no error, existing has games → keep existing | existing games |
| New snapshot has error → use new (show error) | new (error) |
| New snapshot empty + error → use new | new (error) |
| New snapshot empty, existing nil → use new | empty |

### 1H. App settings persistence round-trip

- Save settings with favorites + streaming + zip → reload → values identical
- Unknown composite team IDs are stripped on decode (sanitization)
- Duplicate favorite IDs deduplicated on save
- `meetsOnboardingRequirements`: true iff ≥1 favorite AND ≥1 streaming service

### 1I. NFL season endpoint logic

- Month ≥ August → active season = current year
- Month < August → active season = current year - 1
- Both active and active-1 included
- Season types 2 and 3 for each

---

## Layer 2 — Snapshot / Preview tests (no network, visual regression)

Use `swift-snapshot-testing` (or Xcode's built-in `assertSnapshot`) against `HomeTeamWidgetContentView`.

Build a set of **fixture data factories** covering:

### 2A. Fixture scenarios

| Fixture name | Sport | Previous | Upcoming | Notes |
|---|---|---|---|---|
| `nhl_typical` | NHL | 3 finals with scores | 3 scheduled with records | Standard case |
| `nhl_live_game` | NHL | 2 finals | 1 live (2nd period) + 2 scheduled | Live indicator |
| `nhl_empty_upcoming` | NHL | 3 finals | empty | Off-season |
| `f1_typical` | F1 | 3 GP finals with results | 3 GP scheduled | Race results |
| `f1_upcoming_practice` | F1 | 1 GP final | FP1 + qualifying + sprint | All F1 sessions shown |
| `motogp_typical` | MotoGP | 3 GP finals | sprint + GP only | Practice filtered out |
| `motogp_filtered_by_streaming` | MotoGP | 2 finals | all hidden by streaming filter | Streaming hint message |
| `unconfigured_no_favorites` | — | — | — | "Add favorites" state |
| `unconfigured_favorites_exist` | — | — | — | "Widget not configured" state |
| `api_error` | NHL | stale 3 finals | error message | Error state |
| `racing_season_year_boundary` | F1 | 2024 races hidden, 2025 races shown | — | Year-filtered previous |

### 2B. Snapshot test approach

```swift
// Example: renders widget view with fixture, diffs against stored reference PNG
func testNHLTypical() {
    let state = HomeTeamWidgetContentState(
        referenceDate: .fixture_march_25_2025,
        snapshot: .nhl_typical,
        settings: .fixture_espn_hulu,
        team: .boston_bruins,
        isTeamSelectionConfigured: true
    )
    let view = HomeTeamWidgetContentView(state: state)
        .frame(width: 329, height: 345) // systemLarge macOS widget size
    assertSnapshot(matching: view, as: .image)
}
```

Snapshots are committed as reference images. Any pixel change fails CI and requires explicit re-record.

**Why this matters for the widget**: it catches the full rendering pipeline — filtering, formatting, badge colors, empty states — without touching a real widget instance.

---

## Layer 3 — UI tests (XCUITest, real app process)

### 3A. Onboarding flows (already exist — keep)
- Onboarding shown after reset
- Quick links route to correct Settings sections
- Onboarding dismisses after favorite + streaming + refresh

### 3B. App Group container correctness (critical for widget)

These tests verify the shared container that the **widget reads**.

| Test | What it checks |
|---|---|
| App Group container URL available | Entitlements configured correctly |
| `app_settings.json` written after onboarding | File exists and is valid JSON |
| `favoriteTeamCompositeIDs` non-empty after adding a favorite | Widget picker will show teams |
| `schedule_snapshot_{id}.json` written after refresh | Widget can render data |
| `selectedStreamingServices` persists across app relaunch | Widget inherits filter |

**This is the highest-value test in the entire suite** because empty favorites = empty widget picker = UAT failure.

### 3C. Settings persistence

| Test | Verifies |
|---|---|
| Add favorite → relaunch → favorite still listed | Favorites survive relaunch |
| Reorder favorites → relaunch → order preserved | Order survives relaunch |
| Remove favorite → relaunch → gone | Removal survives relaunch |
| Toggle streaming service → relaunch → still toggled | Streaming survives relaunch |

### 3D. Test version label
- Settings → About shows `AppTestVersion.displayString` matching `^\d+\.\d{3} \(.+\)$`

---

## Layer 4 — Network smoke tests (opt-in, CI nightly)

Run with `HOMETEAM_RUN_NETWORK_TESTS=1`. Not required for every PR.

| Test | Checks |
|---|---|
| ESPN NHL schedule returns ≥1 game | API contract stable |
| ESPN F1 schedule returns ≥1 event | API contract stable |
| MotoGP PulseLive returns ≥1 event | API contract stable |
| NHL standings returns record strings | Standings API stable |
| Decoding succeeds without throwing | No schema drift |

These run against live APIs and can flake — they gate nightly builds, not PRs.

---

## What NOT to automate (leave for UAT)

| Item | Why it cannot be automated |
|---|---|
| Add widget from gallery | OS process (`notificationcenterui`), no XCUITest access |
| Widget configuration sheet on add | OS-rendered sheet |
| Team picker shows correct options | OS-rendered picker inside the above sheet |
| Edit widget (right-click) | OS-rendered menu + sheet |
| Widget re-renders after team/settings change | WidgetKit timeline is OS-scheduled |
| Logo image quality on dark background | Requires human eye |
| "Open at Login" behavior | System service (`SMAppService`), not reliably testable |

---

## UAT checklist — minimum per handoff

These steps require a real Mac, a real signed build, and a human. If the automated layers all pass, these should take under 5 minutes.

### App
- [ ] Launch app fresh → onboarding appears
- [ ] Add a favorite team → onboarding checklist row turns green
- [ ] Add a streaming service → checklist row turns green
- [ ] Onboarding dismisses automatically after both required steps
- [ ] Main scoreboard shows Previous + Upcoming for the added team
- [ ] Live game card has red border (if one is available)
- [ ] Calendar button on upcoming card → opens Google Calendar prefilled correctly
- [ ] Calendar button hover → brightens + scales up
- [ ] "Updated HH:MM" flashes bold after manual refresh
- [ ] Status pill is green when healthy; shows issue count badge + hover card on error
- [ ] Drag-reorder favorites → order persists after relaunch
- [ ] Toggle streaming service → upcoming row updates immediately

### Widget — OS integration (cannot be automated)
- [ ] Add widget from gallery → configuration sheet appears immediately (not blank)
- [ ] Configuration sheet shows favorite teams at top of picker
- [ ] Select a team → widget renders with that team's name and data
- [ ] Previous section shows real recent results
- [ ] Upcoming section shows real upcoming games
- [ ] Right-click → Edit "HomeTeam" → change team → widget updates
- [ ] Changing streaming in Settings → upcoming in widget reflects change on next refresh
- [ ] F1/MotoGP upcoming card shows race name (not empty abbreviation rows)
- [ ] Racing results card shows driver + team, favorite driver highlighted
- [ ] Team and streaming logos are crisp, light-colored, visible on dark background

---

## CI pipeline structure (recommended for rebuild)

```
PR gate (every commit):
  1. qa_unit_gate.sh          ← all unit + snapshot tests, no network
  2. HomeTeamUITests           ← app navigation + App Group JSON correctness

Nightly (scheduled):
  3. Network smoke tests        ← ESPN + MotoGP API contract checks
  4. Screenshot artifacts       ← widget screenshot for human review

Pre-release:
  5. Full UAT checklist         ← human runs the 7 items above
```

---

## Key engineering rules for the rebuild (QA-driven)

1. **One normalization path for streaming service names.** Normalization must happen at parse time, not at display time. No second normalization logic anywhere.

2. **Fixture-injectable `now: Date` on all filtering methods.** Every method that uses `Date()` must accept a `now` parameter. This makes unit tests deterministic without mocking `Date`.

3. **Widget view must accept pure `HomeTeamWidgetContentState` with no init side effects.** The view should be a pure function of its state — snapshot-testable.

4. **App Group write must be synchronous and verified.** After saving settings, the file must exist before the test proceeds. No async fire-and-forget saves.

5. **Accessibility identifiers are a contract.** Every UI element the UI tests reference must have a stable `accessibilityIdentifier`. Treat these like a public API — breaking them is a bug.

6. **Racing session filter must be explicit and tested.** The filter rules (what MotoGP sessions show vs hide) must live in a single function with a complete unit test table. No implicit string-match guesswork.

7. **Snapshot reference images are committed to the repo.** They serve as the visual contract for the widget. Any visual regression fails CI; intentional changes require explicit re-record and commit.
