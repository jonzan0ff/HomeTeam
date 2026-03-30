# QA Master Standards

Standards for AI-assisted development. Apply to any project. Project-specific test plans live in `QA_<PROJECTNAME>.md`.

---

## Philosophy

Three non-negotiable principles:

1. **If a user can see it, the agent must have already seen it.**
2. **If a bug exists, it must be proven before it is fixed.**
3. **Every build must be verified before and after deployment.**

---

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

---

## Definition of Done

A build is ready for human review only when:

- All automated tests pass locally
- All automated tests pass in production
- All critical flows executed end-to-end
- Screenshots captured for all key screens
- No unexpected visual regressions
- Logs are clean (no silent failures)
- Agent explicitly confirms readiness

---

## Test-First, Always

- Write tests before writing features when possible
- At minimum, write tests alongside features in the same commit
- Never ship a feature without test coverage
- Tests are not afterthoughts — they are the proof the feature works

---

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

---

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

---

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

---

## Regression Rule

When a regression is reported — especially if the user says it was just introduced:

1. Check git log and diff against the last known working state **first**
2. Reproduce the exact failure via the simplest possible method before touching any code
3. Never change unrelated systems to fix a localized problem
4. User temporal signals ("you just broke this") are high-confidence — weight them above your own hypothesis
5. No code changes until the cause is confirmed, not guessed

---

## Change Impact Rule

Before making any change — code, config, or external service:

1. **Search before changing** — find every reference to what you're modifying across the entire project
2. **Cross-app awareness** — if the system has multiple apps with shared infrastructure, changes in one can break another
3. **External dependencies** — if a change touches auth, URLs, env vars, or third-party config, enumerate every place that references the old value: code, environment variables, and dashboard settings
4. **State the impact** — before committing, list what else is affected and confirm nothing is missed
5. **If removing or renaming something** — confirm zero remaining references first; do not assume the change is isolated

---

## Post-Deployment Verification

Any time it is technically possible to observe the result after deployment, verify it:

- If there's a URL, hit it
- If there's a UI, screenshot it
- If there's an API, call it
- If there's a database change, query it

Production verification is not optional. If you can see it, check it.

---

## Dedicated QA Accounts

- Use a dedicated QA test account for all automated tests — never depend on real user data
- The QA account should be auto-provisioned by tests if missing
- Protect the QA account from deletion and editing in admin interfaces
- Tests should clean up after themselves but never delete the QA account itself

---

## Test Resilience

- Tests must not depend on AI output being deterministic — add fallback paths for non-deterministic responses
- Tests must not depend on exact counts when background processes (timers, triggers) can add records between assertions
- Tests must manage their own state: set up preconditions in beforeAll, restore original state in afterAll
- Tests should not depend on execution order across files — each file must be independently runnable
- Sequential tests within a file are fine when operations build on each other

---

## Release Flow

1. Agent runs full test suite locally
2. Agent pushes code
3. Deployment triggers automatically (via git push, not CLI tools)
4. Agent runs full test suite against production
5. Agent confirms all green
6. Build is ready for human review

---

## What This System Does Not Do

- Replace human judgment about UX quality
- Infer user intent without verification
- Fix bugs without reproduction
- Skip production verification because localhost passed
- Assume a change is isolated without checking

---

## Final Standard

Automate everything deterministic.
Visually verify everything user-facing.
Prove every bug before fixing it.
Verify every deployment after shipping it.

No exceptions.
