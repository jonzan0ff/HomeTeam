# HomeTeam — Agents & Project Rules

Single source of truth for scope, engineering behavior, and quality gates. Product name shown to users: **HomeTeam**.

## Priority

1. Latest explicit instruction in the current thread.
2. This file.

If they conflict, follow (1) and say what was superseded.

---

## Surfaces

| Surface | Location |
|--------|-----------|
| macOS app | `macos/HomeTeamApp` |
| Widget | `macos/HomeTeamExtension` (WidgetKit) |

---

## macOS app — requirements

1. User picks **favorite teams or drivers** across supported sports; favorites are **reorderable** and **removable**; order and state **persist**.
2. Main window lists favorites **in order**. Each favorite shows:
   - **Summary** (sport-specific: team sports vs racing).
   - **Previous** results row.
   - **Upcoming** schedule row.
3. **Settings** are reachable from the app (including context menu / right-click where appropriate).
4. **Streaming** choices in Settings filter **upcoming** only (not previous) in app and widget.

---

## Widget — requirements

1. **One team or driver per widget instance**; user configures at add time and via **Edit HomeTeam Widget…**.
2. Widget reads the same **persisted settings and schedule snapshots** as the app (shared container / agreed store).
3. **Refresh policy**: about **5 minutes** while a live event is active; about **daily** otherwise (unless product changes this).
4. Widget UI should match the product’s empty, error, and loading expectations (no silent fake data).

---

## First install, onboarding, and Settings

### First launch / onboarding

1. Until setup is complete, the app shows **onboarding** that explains that **Settings** holds required steps.
2. **Required to finish onboarding**: at least one **favorite** and at least one **streaming provider**. **Location (ZIP)** is optional for completing onboarding.
3. Onboarding exposes **shortcuts** into the right Settings sections (Favorites, Streaming, Location).
4. **Reset setup** (where offered) clears favorites and streaming choices so onboarding can run again; behavior must stay explicit and safe.

### Settings — sections

1. **Favorite Teams**: add, remove, **drag/drop reorder**, **Hide during off-season** per favorite.
2. **Streaming Services**: drives upcoming filtering in app + widget.
3. **Location**: ZIP entry; resolve to human-readable place text when possible.
4. **Notifications**: game/race start (watchable rules may be hard-coded); **final scores** for completed events.
5. **About**: shows the **test handoff version** string (see QA below), not only the Xcode bundle version.

All Settings state **persists** and is **consistent** for the main app and the widget extension.

---

## Sports and data (summary)

- **Team sports**: NHL, NFL, MLB, NBA, MLS, Premier League — summary fields include record, place, L10, streak (regular-season context).
- **Racing**: F1, MotoGP — favorites are **drivers**; summary emphasizes standings-style fields; **previous** shows race name, podium, favorite highlighted; **only GP/race finals** for previous (not practice/sprint as “previous race”); qualifying handled per product rules in code.
- **Branding**: use real logos when available; avoid generic placeholders only when the source truly has nothing. Controls show clear **hover** affordance.

(Detailed parsing and edge cases live in code and tests; this file states intent, not every API quirk.)

---

## Mandatory reproduction, evidence, and testing

### No guess-and-ship

1. For a **bug fix** or behavior change: **reproduce first** (steps, failing test, log, or screenshot). Stating a cause without evidence is not enough to change code.
2. If reproduction is **uncertain**, add **minimal instrumentation** or a **narrowed test**, decide what result proves which hypothesis, then act. Remove or promote that instrumentation (do not leave endless debug paths in production without an owner).
3. **Done** means: build passes (app + widget), **relevant automated tests** pass or were added, impacted **manual checks** were run, and the outcome is described with **evidence** (test name, log line, checklist item), not “should work.”

### Automated lanes (use the repo scripts)

- **Default gate (no live network)**: `macos/scripts/qa_unit_gate.sh` — must pass before any handoff that asks the user to build for verification. CI runs this with `CI=true` as applicable.
- **Live / snapshot QA** (network): `macos/scripts/qa_frontend_ui.sh`, `macos/scripts/capture_widget_screenshot.sh` — when changes touch widget rendering or live data.
- **UI tests** (Accessibility, full app launch): `macos/scripts/qa_ui_tests.sh` and related scripts under `macos/scripts/` — when changing flows those tests cover.
- **Widget / extension sanity**: `macos/scripts/qa_widget_registration.sh` when registration or embedding changes.

Exact env vars and desktop automation rules stay in the **scripts** and **CI workflows**; agents must follow those files when running commands, not invent ad-hoc automation.

### Manual regression (minimum when the area is touched)

- Launch app, open Settings, sidebar works.
- Favorites: add / reorder / remove / relaunch persistence.
- Streaming toggles change **upcoming** rows as expected.
- ZIP resolves when valid.
- Main board shows previous + upcoming for mixed favorites.
- Widget: add from gallery, edit, instance shows intended team; racing rows follow GP rules; logos look right for sampled favorites.

### Handoff version (when asking the user to run a build)

1. Run `qa_unit_gate.sh` successfully before the ask; report pass/fail with evidence.
2. Bump `AppTestVersion.displayString` in `macos/HomeTeamApp/AppTestVersion.swift` (`0.00X (Mon DD HH:MM)`), **+0.001** per handoff, time = handoff time.
3. Handoff line must include: **Please test version 0.00X (Mon DD HH:MM)** matching that string; user confirms in **Settings → About**.

---

## Code — best practices

1. **Single source of truth** for settings and filtering; no duplicate rules in UI-only code.
2. **Small, scoped changes** with tests preferred over large unverified rewrites.
3. **Stable IDs** for teams/settings keys; use explicit **migrations** when renaming persisted models.
4. **APIs are untrusted**: parse defensively, normalize in one place, test edge cases.
5. **No silent “fixups”** that hide bad data; prefer visible errors or clear empty states.
6. **UI state** that matters must be **observable** and **persisted** predictably.
7. **Idiomatic Swift / SwiftUI** for current targets; avoid unnecessary abstraction and defensive noise.
8. **Do not claim done** without running the checks above for the changed surface.

## Code — style

1. Match surrounding file style (naming, formatting, comment density).
2. No emojis in product copy or repo docs unless the user asks.
3. Keep **README** and this file **concise**; put long QA mechanics in `qa/README.md` where they already live.

---

## Regression telemetry (optional cadence)

Telemetry and test-retirement policy live under `qa/` (e.g. `qa/history`, `qa/test-retirement-policy.json`). Agents follow `qa/README.md` for details; this file only notes that the project may use that system.

---

## Bug status words

| Term | Meaning |
|------|--------|
| **Done** | Fixed; evidence attached (tests + checklist as needed). |
| **Failed** | Not fixed, regressed, or incomplete. |
| **Blocked** | Only for missing requirement, missing access, or impossible capability — never for effort or frustration. |

---

Keep requirements here **explicit** so missing work is obvious. When in doubt, **reproduce, measure, then change**.
