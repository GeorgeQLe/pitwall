# Todo - Pitwall

> Current phase: 1 of 5 - Foundation And Pacing Core
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Task pipeline is healthy; no issues found. Ready for `$run`.

## Phase 1: Foundation And Pacing Core

> Test strategy: tdd

**Goal:** Establish the clean-room Swift project foundation and a tested provider-agnostic pacing core before implementing provider credentials, networking, or UI.

**Scope:**
- Create the initial Swift package/app structure for independently authored Pitwall code.
- Define provider-agnostic domain models for provider status, confidence, pacing state, recommendations, reset windows, and usage snapshots.
- Implement deterministic pacing calculations for weekly and session windows, daily budget, today's usage, capped state, and action guidance.
- Keep this phase free of real provider networking, credential storage, and production UI.

**Acceptance Criteria:**
- A Swift package exists and `swift test` can run locally.
- Pacing tests cover weekly and session calculations, ignore-window behavior, threshold labels, capped utilization, daily budget, and unknown-today behavior.
- Domain models can represent Claude, Codex, Gemini, and future providers without forcing provider-specific quota shapes into one schema.
- The implementation remains clean-room: no copied Swift/Xcode source, assets, screenshots, or tests from the prior ClaudeUsage lineage.
- The scaffold does not store credentials, read provider local files, or call provider networks.

### Execution Profile
**Parallel mode:** serial
**Integration owner:** main agent
**Conflict risk:** medium
**Review gates:** correctness, tests, security, docs/API conformance

**Subagent lanes:** none

### Tests First
- [x] Step 1.1: Create the Swift test harness and write failing tests for the pacing core acceptance criteria
  - Files: create `Package.swift`, create `Tests/PitwallCoreTests/PacingCalculatorTests.swift`, create `Tests/PitwallCoreTests/DailyBudgetTests.swift`
  - Cover weekly pace ratio thresholds: underusing, behind pace, on pace, ahead of pace, warning, critical, capped
  - Cover session pace ignore windows: first 15 minutes and last 5 minutes
  - Cover weekly pace ignore windows: first 6 hours and last 1 hour
  - Cover daily budget with fractional days remaining and unknown local-midnight baseline
  - Tests fail at this point because the core implementation does not exist yet
  - Red-phase validation: `swift test` fails on missing `PacingCalculator`, `PacingLabel`, `RecommendedAction`, and `UsageSnapshot` symbols after the package manifest loads successfully

### Implementation
- [x] Step 1.2: Create the provider-agnostic core model layer
  - Files: create `Sources/PitwallCore/ProviderModels.swift`
  - Include provider identifiers, provider status, confidence labels, pacing labels, actions, reset windows, usage snapshots, and provider state containers
  - Define public, Equatable model primitives required by the red tests:
    - `PacingLabel` cases: `underusing`, `behindPace`, `onPace`, `aheadOfPace`, `warning`, `critical`, `capped`, `notEnoughWindow`
    - `RecommendedAction` cases: `push`, `conserve`, `switchProvider`, `wait`, `configure`
    - `UsageSnapshot` with `recordedAt: Date` and `weeklyUtilizationPercent: Double`
    - `TodayUsageStatus` cases: `exact`, `estimatedFromSameDayBaseline`, `unknown`
    - Result containers for pace evaluation, daily budget, and today's usage with the fields referenced by the tests
  - Also add provider-agnostic state models from `specs/pitwall-macos-clean-room.md`: provider identifiers, display names, status, confidence labels, reset windows, headline/primary/secondary values, confidence explanations, and provider-specific payload escape hatches
  - Keep the file free of credentials, provider network calls, local file reads, or provider-specific quota schemas
  - Red-phase validation: `swift test` builds `PitwallCore` with the new models and fails as expected because Step 1.3 has not introduced `PacingCalculator` yet.
- [x] Step 1.3: Implement pacing calculations and recommendation mapping
  - Files: create `Sources/PitwallCore/PacingCalculator.swift`
  - Implement weekly and session pace ratios, ignore-window handling, capped handling, daily budget, today's usage baseline behavior, and recommendation output
  - Use the Step 1.2 model types:
    - Return `PaceEvaluation` from `evaluateWeeklyPace(utilizationPercent:windowStart:resetAt:now:)` and `evaluateSessionPace(utilizationPercent:windowStart:resetAt:now:)`
    - Return `DailyBudget` from `dailyBudget(weeklyUtilizationPercent:resetAt:now:retainedSnapshots:calendar:timeZone:)`
  - Weekly pace rules:
    - Ignore the first 6 hours after `windowStart` and the last 1 hour before `resetAt`, returning `.notEnoughWindow`, `.configure`, and nil ratio/expected utilization.
    - Compute expected utilization as elapsed fraction of the full window multiplied by 100.
    - Compute pace ratio as actual utilization divided by expected utilization.
  - Session pace rules:
    - Ignore the first 15 minutes after `windowStart` and the last 5 minutes before `resetAt`.
    - Use the same expected-utilization and threshold shape as weekly pace.
  - Threshold/action mapping:
    - `utilizationPercent >= 100`: `.capped` and `.wait`
    - ratio `< 0.50`: `.underusing` and `.push`
    - ratio `0.50..<0.85`: `.behindPace` and `.push`
    - ratio `0.85...1.15`: `.onPace` and `.push`
    - ratio `> 1.15...1.50`: `.aheadOfPace` and `.conserve`
    - ratio `> 1.50...2.00`: `.warning` and `.conserve`
    - ratio `> 2.00`: `.critical` and `.wait`
  - Daily budget rules:
    - Remaining utilization is `max(0, 100 - weeklyUtilizationPercent)`.
    - Days remaining is `(resetAt - now) / 86400`, clamped to a minimum of `1.0 / 24.0`.
    - Daily budget is remaining utilization divided by clamped days remaining.
    - Today's usage should compare current weekly utilization against the closest retained snapshot before local midnight; if none exists, use the earliest same-day snapshot as an estimate; if neither exists, return unknown.
  - Keep this step deterministic and free of provider networking, credentials, local provider files, or UI concerns.
  - Validation: `swift test` passes 10 tests after implementing `PacingCalculator` and correcting daily-budget timestamp fixtures to straddle an actual UTC local-midnight boundary.
- [x] Step 1.4: Add clean-room project scaffolding notes for future app targets
  - Files: create `Sources/PitwallCore/PitwallCore.swift`, modify `README.md`
  - Document how to run `swift test` and keep implementation inputs tied to specs and public/platform docs only
  - Implementation plan for next run:
    - Read `README.md`, `CLEAN_ROOM.md`, and `specs/pitwall-macos-clean-room.md` only for the existing clean-room rules and project positioning.
    - Create `Sources/PitwallCore/PitwallCore.swift` as a lightweight public module anchor for future app targets. Keep it free of provider logic, credentials, local file reads, networking, UI code, assets, or copied upstream implementation details.
    - Update `README.md` to state that the current SwiftPM target is `PitwallCore`, tests run with `swift test`, and future app targets must use specs/public platform documentation as inputs rather than prior ClaudeUsage source or assets.
    - Keep this step documentation/scaffold-only; do not introduce provider adapters, app targets, credential storage, or production UI.
    - Validation: `swift test` passes 10 XCTest cases with no warnings emitted.

### Green
- [ ] Step 1.5: Run the core test suite and verify all Phase 1 tests pass
  - Command: `swift test`
- [ ] Step 1.6: Refactor model naming and calculator boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/ProviderModels.swift`, modify `Sources/PitwallCore/PacingCalculator.swift`, modify tests only as needed to clarify behavior without weakening coverage

### Milestone: Phase 1 Foundation And Pacing Core
**Acceptance Criteria:**
- [ ] A Swift package exists and `swift test` can run locally.
- [ ] Pacing tests cover weekly and session calculations, ignore-window behavior, threshold labels, capped utilization, daily budget, and unknown-today behavior.
- [ ] Domain models can represent Claude, Codex, Gemini, and future providers without forcing provider-specific quota shapes into one schema.
- [ ] The implementation remains clean-room: no copied Swift/Xcode source, assets, screenshots, or tests from the prior ClaudeUsage lineage.
- [ ] The scaffold does not store credentials, read provider local files, or call provider networks.
- [ ] All phase tests pass
- [ ] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none recorded yet
- Tech debt / follow-ups: none recorded yet
- Ready for next phase: no
