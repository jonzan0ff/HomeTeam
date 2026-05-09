# HomeTeam — Surfaces and Build Verification Routing

**Read this file at the start of any task that edits code in this project.** Match each changed file against the surface sections below. Run the build-verification commands listed for every surface that matched — and only those. Don't run widget verification for menu bar changes, don't skip snapshot tests when the widget is touched.

Surfaces are listed in roughly the order you're most likely to touch them. Each surface's `Files` list uses glob patterns; a surface is "changed" if any of those patterns matches a file in your diff.

---

## Widget (WidgetKit extension)

The large widget that shows schedule + scores for the user's followed teams. Three sport variants — NHL, MotoGP, F1 — each with dim and lit modes. This is HomeTeam's primary user surface.

**Files:**
- `macos/HomeTeamExtension/**`
- `macos/Shared/Views/**` (any SwiftUI views imported by the widget)
- `macos/Shared/Models/HomeTeamGame.swift`
- `macos/Shared/Models/ScheduleSnapshot.swift`

**Build Verification when changed:**
- `xcodebuild test -project macos/HomeTeam.xcodeproj -scheme HomeTeam -destination "platform=macOS,arch=arm64" -only-testing HomeTeamTests` — unit + snapshot tests
- `./macos/scripts/build_verification_widget_snapshot.sh` — captures live widget in both dim and lit modes, per sport (QA Mac only — pluginkit-loads the DerivedData extension so `/Applications/HomeTeam.app` is undisturbed)
- Update `qa/review.html` widget section with new v{X.Y.Z} captures

---

## Menu bar popover (the dropdown)

The SwiftUI body that appears when the user clicks the status item. Mockups live in `qa/mockups/popover/`. Rev 2 shipped April 2026.

**Files:**
- `macos/HomeTeamApp/Views/MenuBarPopoverView.swift` (or wherever MenuBarPopoverView lives)
- `macos/HomeTeamApp/MenuBarController.swift`
- `macos/HomeTeamApp/AppState.swift`

**Build Verification when changed:**
- `xcodebuild test -project macos/HomeTeam.xcodeproj -scheme HomeTeam -destination "platform=macOS,arch=arm64" -only-testing HomeTeamTests/MenuBarPopoverSnapshotTests`
- `./scripts/build_verification_menubar_screenshots.sh <version>` — refreshes `qa/mockups/popover/`
- Update `qa/review.html` "Menu Bar Popover" section if scenarios changed

---

## Menu bar status item (the icon itself)

The `NSStatusItem` in the system menu bar — base icon + green dot when a game is live + update indicator. Must be captured live (menu bar compositor), not via `ImageRenderer`.

**Files:**
- `macos/HomeTeamApp/MenuBarController.swift`
- `macos/HomeTeamApp/Assets.xcassets/MenuBarIcon.imageset/**`

**Build Verification when changed:**
- **Gap:** no dedicated status-item capture script exists. If you change this surface, capture manually via `screencapture -x -R` per `~/.claude/rules/menu-bar-screenshots.md` (Finder activated first), or flag to the user that a capture script needs to be built.

---

## Main app window / app views

The non-menu-bar SwiftUI that the user interacts with when they open HomeTeam properly.

**Files:**
- `macos/HomeTeamApp/Views/**` (excluding MenuBarPopoverView.swift which belongs to the popover surface above)
- `macos/HomeTeamApp/**/*.swift` (top-level app files)

**Build Verification when changed:**
- `xcodebuild test -project macos/HomeTeam.xcodeproj -scheme HomeTeam -destination "platform=macOS,arch=arm64" -only-testing HomeTeamTests`
- Visual verification via screenshot of the app window (manual / scripted — no standard script yet)
- `./macos/scripts/build_verification_frontend_ui.sh` if it applies to your change

---

## Schedule data layer (no visual)

The models, services, persistence, and parsers that turn upstream API data into `HomeTeamGame` records. Changes here have no visual surface — unit tests are the full story.

**Files:**
- `macos/Shared/Models/**`
- `macos/Shared/Services/**`
- `macos/Shared/Persistence/**`

**Build Verification when changed:**
- `xcodebuild test -project macos/HomeTeam.xcodeproj -scheme HomeTeam -destination "platform=macOS,arch=arm64" -only-testing HomeTeamTests`
- If persistence schema changed: also the `AppGroupSmokeTest/` project

**Do NOT run:**
- Widget capture scripts (no visual change)
- Menu bar popover snapshot tests (no visual change)

---

## App Group / entitlements / provisioning

Changes to the App Group, entitlements, or provisioning profile shape. This is the class of change that silently breaks the widget's ability to read cached state.

**Files:**
- `macos/Config/**` (entitlements)
- `macos/project.yml`
- Anything touching `group.com.hometeam.shared`

**Build Verification when changed:**
- Full build: `xcodebuild -project macos/HomeTeam.xcodeproj -scheme HomeTeam -configuration Debug -allowProvisioningUpdates build`
- Verify widget profile has App Groups: `security cms -D -i <path-to-embedded.provisionprofile> | plutil -p - | grep -A5 application-groups`
- `AppGroupSmokeTest/` project if major
- After any `xcodegen generate`: `git checkout -- macos/Config/` to restore entitlements (xcodegen wipes them)

---

## Auto-update / release

GitHub Releases poller + install flow.

**Files:**
- `macos/HomeTeamApp/Services/UpdateService.swift`
- `scripts/release.sh`
- `macos/project.yml` (when `MARKETING_VERSION` changes)

**Build Verification when changed:**
- Build + unit tests
- A full `./scripts/release.sh` dry run is the only end-to-end test

---

## Documentation / policy (no build verification)

Doc-only and policy-only changes that affect no user surface and need no build-verification run.

**Files:**
- `*.md` (anywhere — README, build-verification-plan, surfaces, etc.)
- `.claude/**` (project policy: rules, hooks, surfaces, settings)
- `docs/**`
- `README*`, `LICENSE*`, `.gitignore`, `.gitattributes`

**Build Verification when changed:** None. The global pre-push hook (`~/.claude/hooks/pre-push-check.sh`) recognizes this surface and bypasses the build-verification marker gate when *every* file in the diff matches it. If a single non-doc file is also in the diff, the normal surface routing applies and build verification is required.

---

## How to add a new surface

1. Name it after the user-visible thing (e.g. "widget", "menu bar popover"), not the code module
2. List every file whose edit would affect that user-visible thing — be generous
3. List every build-verification command to run, in order
4. If a surface has no build verification yet, say so as a gap
5. Add a section to `qa/review.html` for any surface with visual output
