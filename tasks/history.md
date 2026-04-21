# History

## 2026-04-21

- Phase 1 Step 1.2 completed: added provider-agnostic core models for provider identity/status/confidence, pacing labels, recommendation actions, reset windows, usage snapshots, today's usage, pace evaluation, daily budget, normalized pacing state, provider actions, and provider-specific payload escape hatches.
- Validation: `swift test` builds the `PitwallCore` target with the new model layer and fails as expected because Step 1.3 has not implemented `PacingCalculator` yet.
- Phase 1 Step 1.1 completed: added a SwiftPM manifest, a red-phase `PitwallCore` target placeholder, and XCTest coverage for weekly/session pacing thresholds, ignore windows, capped utilization, daily budget, and today's usage baseline behavior.
- Validation: `swift test` reaches test compilation and fails as expected because the Step 1.2/1.3 core symbols are not implemented yet (`PacingCalculator`, `PacingLabel`, `RecommendedAction`, `UsageSnapshot`).
