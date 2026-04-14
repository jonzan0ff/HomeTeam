# Release Pipeline — Protected

The project has a fully-wired Apple-approved Developer ID distribution pipeline. **Do not modify any of these files without understanding the consequences** — breakage is silent and only surfaces on end-users' Macs after notarization and install.

## Protected files

| File | What it does |
|---|---|
| `scripts/release.sh` | Runs `xcodebuild archive` → `xcodebuild -exportArchive` → notarize → staple → GitHub Release |
| `macos/exportOptions.plist` | Tells xcodebuild to sign with Developer ID using manual provisioning profiles |
| `macos/project.yml` — `DEVELOPMENT_TEAM`, bundle IDs, `ENABLE_HARDENED_RUNTIME` | Must match the installed provisioning profiles and keep hardened runtime off in the source (release.sh overrides at build time) |

## What not to do without coordination

1. **Do not change bundle IDs** — `com.hometeam.app` and `com.hometeam.app.extension` are bound to the `HomeTeam Direct` and `HomeTeam Extension Direct` provisioning profiles. Renaming breaks signing.
2. **Do not change `DEVELOPMENT_TEAM`** — must stay `Q4MZVR4MU5`.
3. **Do not add new entitlements** without also:
   - Enabling the capability on the App ID at https://developer.apple.com/account/resources/identifiers/list
   - Regenerating the provisioning profile with the new capability
   - Installing the new profile into `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
4. **Do not add new targets** (extra widget, helper tool) that need their own provisioning profile without creating the profile first.
5. **Do not delete or edit `macos/exportOptions.plist`** — the `provisioningProfiles` dictionary is exactly matched to the installed profiles.
6. **Do not modify `scripts/release.sh`** unless you understand the SIGPIPE-under-pipefail gotcha in the verification checks and the `STRIP_INSTALLED_PRODUCT=NO` requirement to avoid launchd POSIX error 163.

## If you need to ship

1. Commit your changes
2. Bump `MARKETING_VERSION` in `macos/project.yml`
3. `cd macos && xcodegen generate && cd .. && git checkout -- macos/Config/`
4. Commit the version bump
5. Run `./scripts/release.sh` — it archives, exports, notarizes, staples, and publishes to `jonzan0ff/HomeTeam` releases

## Shared infrastructure

- Developer ID Application certificate is in the login keychain (Team ID `Q4MZVR4MU5`)
- Notarytool keychain profile is named `PrintStatus-Notary` — shared across all four Mac apps (HomeTeam, What to Watch, Dorothy, Print Status). The name is a label; it stores Apple ID + app-specific password credentials that work for any app under the same team.
- Provisioning profiles are in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` keyed by UUID. Don't delete that directory.

## History

Root cause of the "widget shows placeholder" bug on Print Status (2026-04-14): an earlier version of `release.sh` re-signed the widget with a minimal `.entitlements` file, silently stripping `com.apple.developer.team-identifier`. Without that entitlement the sandboxed widget can't resolve its App Group container and the UI falls through to the "configure" placeholder. The elegant fix — this pipeline — uses Xcode's one-pass distribution path so no re-signing is ever required.
