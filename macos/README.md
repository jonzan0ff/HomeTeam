# Caps Widget macOS Shell

This directory scaffolds a native macOS app + WidgetKit extension for local-first use.

## Prerequisites
- Install full Xcode (not only Command Line Tools)
- Optional: Homebrew `xcodegen` (not required here; local binary is included at `./tools/xcodegen`)

## Generate project
```bash
cd macos
./tools/xcodegen generate
open CapsWidget.xcodeproj
```

## First run checklist
1. In Xcode, set your Team for both targets.
2. Keep **Automatically manage signing** enabled.
3. Build and run `CapsWidgetApp`.
4. In app Settings, enable **Open at Login**.

## Dock icon (Capitals logo)
1. Save a square dark-compatible Capitals logo as:
   - `macos/assets/caps_logo_dark.png`
2. Generate app icon sizes:
```bash
./scripts/generate_appicon.sh
```
3. Rebuild app target.

## What is implemented now
- SwiftUI app shell with basic game list + manual refresh
- `Open at Login` toggle via `SMAppService.mainApp`
- Local per-target snapshot storage (Personal Team friendly)
- Widget timeline policy scaffold (5 min when live, daily otherwise)
- Widget fetches ESPN data directly on timeline refresh

## Next implementation steps
- Expand widget UI to closely match the mac app scoreboard style
- Add calendar deep-link action from app rows
- Add richer error/offline states and telemetry logging
