# HomeTeam — QA Strategy

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
| `"São Paulo GP"` | `"São Paulo GP"` (unchanged, 3-word) |
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
| `nhl_live_game` | NHL | 1 final | 1 live (2ND • 8:42) + 1 scheduled | Live chip + score |
| `nhl_offseason` | NHL | 1 final | empty | Off-season zzz message |
| `f1_typical` | F1 | 2 GP finals with P1-P3 results | 3 GP scheduled with TV+ | Race results |
| `motogp_typical` | MotoGP | 2 GP finals (DNF + P4) | 3 GP scheduled with FS1 | Abbreviated names |
| `unconfigured` | — | — | — | "No team selected" placeholder |
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
