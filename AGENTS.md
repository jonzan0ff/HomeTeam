# HomeTeam Project

## Purpose
Single source of truth for product scope, engineering standards, and QA gates for the HomeTeam macOS app + widget.

## Priority Order
1. Latest explicit user instruction in the thread.
2. This `AGENTS.md`.

If conflicts exist, follow the highest-priority source and note what was superseded.

## Scope

### Product Surface
1. Native macOS SwiftUI app in `macos/HomeTeamApp`.
2. WidgetKit extension in `macos/HomeTeamExtension`.
3. Product name shown to users is `HomeTeam`.

### Core Experience
1. Users select favorite teams/drivers across supported sports.
2. Favorites are reorderable and removable; order/state persist.
3. Main app renders all favorites in order.
4. Each favorite card shows:
   - summary row (sport-specific)
   - previous results row
   - upcoming schedule row
5. Main app supports quick access to settings (including context-menu/right-click).

### Widget Experience
1. Widget is team/driver specific per instance (one favorite per widget instance).
2. Widget supports configuration during add and later via `Edit HomeTeam Widget...`.
3. Widget uses shared persisted settings/snapshots.
4. Widget refresh cadence:
   - 5min refresh during live events
   - daily refresh otherwise

### Settings Experience
1. Settings sections include:
   - Favorite Teams
   - Streaming Services
   - Location
   - Notifications
2. Favorite Teams section supports:
   - add
   - delete
   - drag/drop reorder
   - `Hide During Off-season` control per favorite
3. Streaming Services selection drives filtering behavior in app + widget for upcoming but not previous games/races.
4. Location is ZIP-based and resolves to displayable location text.
5. Notifications include:
   - game/race start notifications (watchable logic allowed to be hard-coded)
   - final result notifications for all completed events
6. Settings state persists locally and syncs to shared/widget consumers.

### Sports and Data Behavior
1. Team sports: NHL, NFL, MLB, NBA, MLS, Premier League.
2. Racing sports: F1 and MotoGP.
3. F1/MotoGP favorites are driver-centric entries.
4. Team sports summary row fields: record, place, L10, streak (regular-season context).
5. F1/MotoGP summary row fields: place, points, wins, podiums (drivers standings focus).
6. F1/MotoGP previous results display:
   - race name
   - podium finishers
   - favorite placement (bold)
   - only podium items if favorite is already on podium
7. Previous race event logic only displays GP/race results and ignores practice/sprint/prelim data. After qualifying race, display the podium and favorite racer under upcoming races.

### Branding and Visual
1. Use current asset logo as-is, edge-to-edge display where expected.
2. Provider and team/driver logos render as real assets when available; avoid generic fallback unless source truly missing.
3. Interactive controls provide visible hover affordance.


## QA Requirements

### Definition of Done
A task is `Done` only when all are true:
1. Build succeeds for app and widget targets.
2. Relevant automated tests pass (or new tests added for changed behavior).
3. Manual regression checklist for impacted areas is executed.
4. No known requirement in changed scope is silently skipped.
5. Result is reported with evidence, not assumption.

### Regression Checklist (Minimum)
1. App launch, settings navigation, and no broken sidebar interaction.
2. Add/reorder/remove favorites persists after relaunch.
3. Streaming provider toggles immediately affect upcoming rows.
4. ZIP entry resolves and displays location text.
5. Main board renders previous/upcoming for mixed sports favorites.
6. Widget appears in gallery, can be added, configured, and edited.
7. Widget shows selected favorite, not stale/legacy identifier.
8. Racing: upcoming GP appears when present; previous uses GP race result, not prelim.
9. Racing: standings row fields are populated for driver favorites.
10. Logos: app logo, provider icons, and sports logos display correctly for tested favorites.

### Test Strategy
1. Unit tests for:
   - data parsing/normalization
   - filtering logic
   - settings persistence/migration
   - favorite ordering
2. Integration tests for:
   - repository/client contract mapping
   - shared app/widget snapshot flow
3. UI tests for:
   - settings interactions
   - favorite reorder/delete
   - widget intent selection path (where automatable)
4. Add regression tests for every production bug fixed in unstable areas.

### Regression Telemetry
1. Persist test-run telemetry for optimization in `qa/history` (maintained on `qa-history` branch).
2. Use `qa/test-retirement-policy.json` as the threshold source of truth.
3. Default retirement flow is two-step: demote cadence first, then retire after sustained no-regression evidence.
4. Keep detailed mechanics in `qa/README.md`; keep only high-level guardrails in `AGENTS.md`.

### Permission-Minimizing Workflow
1. Default to prompt-free QA lanes in this repo; avoid desktop/session automation.
2. Run QA through repo scripts first:
   - `macos/scripts/qa_unit_gate.sh` — full `HomeTeamTests` bundle with **no live network** (widget snapshot + API smoke tests `XCTSkip` unless `HOMETEAM_RUN_NETWORK_TESTS=1`).
   - `macos/scripts/qa_frontend_ui.sh` — widget snapshots + regression picks; requires live data (`HOMETEAM_RUN_NETWORK_TESTS=1` by default in script).
   - `macos/scripts/capture_widget_screenshot.sh`
   - `macos/scripts/qa_widget_registration.sh`
3. Desktop/session automation is forbidden by default.
4. Do not run `open`, `osascript`, Accessibility/AppleEvents flows, desktop `screencapture`, or UI-test launch commands (`xcodebuild` with `HomeTeamUITests` or `-only-testing:HomeTeamUITests/...`) unless the user explicitly requests a security override in the current thread.
5. If and only if override is explicitly requested, run desktop automation only through `macos/scripts/desktop_automation_gate.sh` with `HOMETEAM_DESKTOP_AUTOMATION_OVERRIDE=1`.
6. Without explicit override request, treat any task that needs desktop automation as `Blocked`.
7. Keep build output under `/tmp/HomeTeamDerived*` and QA artifacts under `macos/artifacts/*`.
8. Keep writes inside workspace + `/tmp`; do not write ad-hoc files elsewhere in `$HOME`.
9. If elevated access is still required, request the narrowest command prefix once and reuse it.

### Bug Status Vocabulary
1. `Done`: fixed and verified with tests/checklist evidence.
2. `Failed`: attempted but not fixed, regressed, or incomplete.
3. `Blocked`: only if requirement is unclear, required system access/tooling is unavailable, or model capability is insufficient.

Time spent, complexity, or frustration are never `Blocked`; those are `Failed` until resolved.

## Code Best Practices
1. Keep a single source of truth for settings and filtering rules.
2. Do not hard-code UI filtering that bypasses settings 
3. Avoid silent fallbacks that hide data-quality problems; surface actionable errors.
4. Preserve stable identifiers and add explicit migrations when renaming keys/models.
6. Prefer small, scoped changes with tests over large unverified rewrites.
7. Treat API data as unstable: parse defensively, normalize centrally, and test edge cases.
8. Ensure UI state changes are observable and persisted deterministically.
9. Validate behavior in running app/widget before claiming completion.
10. Never claim untested functionality as complete.

## Coding standards

1. Use latest versions of libraries and idiomatic approaches as of today
2. Keep it simple - NEVER over-engineer, ALWAYS simplify, NO unnecessary defensive programming. No extra features - focus on simplicity.
3. Be concise. Keep README minimal. IMPORTANT: no emojis ever

## Delivery Protocol
For each requested batch of work, report:
1. `Done`
2. `Failed`
3. `Blocked`

Keep each item explicit and requirement-mapped so missing work is obvious.
