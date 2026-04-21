# History

## 2026-04-21

- Phase 1 Step 1.4 completed: added a lightweight `PitwallCore` module anchor and updated `README.md` with the current SwiftPM target, `swift test` usage, and clean-room input rules for future app targets.
- Validation: `swift test` passes 10 XCTest cases with no warnings emitted.
- Phase 1 Step 1.3 completed: implemented `PacingCalculator` with deterministic weekly/session pace evaluation, ignore-window handling, capped/action mapping, daily budget calculation, and today's usage baseline behavior.
- Corrected daily-budget test fixtures so UTC calendar tests straddle an actual UTC local-midnight boundary while preserving coverage for exact, estimated, and unknown today-usage states.
- Validation: `swift test` passes 10 tests with no warnings emitted.
- Phase 1 Step 1.2 completed: added provider-agnostic core models for provider identity/status/confidence, pacing labels, recommendation actions, reset windows, usage snapshots, today's usage, pace evaluation, daily budget, normalized pacing state, provider actions, and provider-specific payload escape hatches.
- Validation: `swift test` builds the `PitwallCore` target with the new model layer and fails as expected because Step 1.3 has not implemented `PacingCalculator` yet.
- Phase 1 Step 1.1 completed: added a SwiftPM manifest, a red-phase `PitwallCore` target placeholder, and XCTest coverage for weekly/session pacing thresholds, ignore windows, capped utilization, daily budget, and today's usage baseline behavior.
- Validation: `swift test` reaches test compilation and fails as expected because the Step 1.2/1.3 core symbols are not implemented yet (`PacingCalculator`, `PacingLabel`, `RecommendedAction`, `UsageSnapshot`).
