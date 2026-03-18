# Caps Widget Native macOS Plan

## Goals
- Deliver a native macOS app with a WidgetKit widget that does not depend on a localhost web server.
- Start automatically when the Mac starts (user-controlled Open at Login).
- Show a Capitals-branded dock icon.

## Phase 1: Native Foundation
- Set up `macos/` project structure for:
  - `CapsWidgetApp` (macOS SwiftUI app)
  - `CapsWidgetExtension` (WidgetKit extension)
  - `Shared` (models, schedule fetch service, shared persistence)
- Configure a Personal Team-friendly setup that runs without paid Apple Developer capabilities.

Success criteria:
- Project can be generated/opened in Xcode and both targets build.

## Phase 2: Data + Local Robustness
- Fetch schedule directly from ESPN API from native code.
- Filter to allowed stream providers (Paramount, Amazon, Peacock, HBO, Apple TV, Netflix).
- Persist local snapshot data per target (app + widget) with fallback rendering.
- Add stale data behavior so widget still renders if refresh fails.

Success criteria:
- App can refresh and save snapshot.
- Widget can read and render snapshot without app running.

## Phase 3: Widget Timeline Policy
- Widget shows next 3 games.
- Timeline policy:
  - Refresh every 5 minutes when a live game exists.
  - Refresh daily otherwise.
- Add explicit last-updated fallback state.

Success criteria:
- Widget updates automatically and remains usable when offline.

## Phase 4: Startup + Dock Branding
- Add `Open at Login` toggle using `SMAppService.mainApp`.
- Add Capitals app icon asset set for dock.
- Provide script to generate macOS app icon set from a Capitals logo source image.

Success criteria:
- App appears in dock with Capitals icon.
- User can enable startup at login from app settings.

## Phase 5: Packaging + Validation
- Add runbook for local dev, release build, and signing notes.
- Validate startup, widget loading, and cache fallback by reboot simulation/logout.

Success criteria:
- A reproducible local install and startup workflow exists.
