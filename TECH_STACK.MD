# Tech Stack

These are the tools and services we have experience with across our projects. Not everything here will be relevant to every project — use what fits. But when you need something in one of these categories, default to what we already know unless there's a strong reason not to.

---

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

- **Resend** — Transactional email delivery via custom SMTP *(Camp Clintondale)*

## Hosting & Deployment

- **Vercel** — Hosting, automatic deploys from git push *(Camp Clintondale, What to Watch)*
- **GitHub** — Source control *(all projects)*
- **GitHub Pages** — Static asset hosting for logos and images *(HomeTeam, What to Watch)*
- **GitHub Releases** — Binary distribution for macOS apps *(What to Watch)*
- **xcodegen** — Generates `.xcodeproj` from a declarative `project.yml` *(HomeTeam, What to Watch)*

## Mac / iOS Apps

- **Swift 5.9** — Language for all native Apple targets *(HomeTeam, What to Watch)*
- **SwiftUI** — Declarative UI framework for menu bar popover and widget *(HomeTeam, What to Watch)*
- **AppKit** — Menu bar integration (NSStatusItem, NSPopover, NSMenu) *(HomeTeam, What to Watch)*
- **WidgetKit** — macOS widget extension *(HomeTeam, What to Watch)*
- **App Groups** — Shared container for data between app and widget *(HomeTeam, What to Watch)*

## External APIs

- **ESPN API** — Schedule, scores, and streaming data for NHL, NFL, MLB, NBA, MLS, Premier League, F1 *(HomeTeam)*
- **MotoGP Calendar API** — Race schedule for MotoGP *(HomeTeam)*
- **TMDB API** — TV show/movie search, episode data, watch providers *(What to Watch)*

---

## QA & Testing

Tools and infrastructure used to satisfy `QA_MASTER.MD` standards.

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

- **qa_unit_gate.sh** — Layer 1: xcodegen + xcodebuild unit tests
- **qa_widget_snapshot.sh** — Layer 2: Widget snapshot tests (coverage/record modes)
- **qa_api_tests.sh** — Layer 4: Playwright against localhost
- **qa_api_prod.sh** — Layer 4: Playwright against production
- **collect_test_telemetry.sh** — Extract metrics from xcresult bundles
- **persist_test_history.sh** — Append telemetry to qa-history branch

### Makefile Targets

- `make qa` — Full local gate (unit + snapshot + API)
- `make qa-prod` — Post-deploy verification against production
- `make qa-record` — Re-record snapshot baselines

### QA Principles (from QA_MASTER.MD)

1. If a user can see it, the agent must have already seen it
2. If a bug exists, it must be proven before it is fixed
3. Every build must be verified before and after deployment
4. Tests written alongside code, never after
5. Visual regression on every UI change
6. Production verification is not optional
