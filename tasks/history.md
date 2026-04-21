# History

## 2026-04-21

- Phase 1 Step 1.1 completed: added a SwiftPM manifest, a red-phase `PitwallCore` target placeholder, and XCTest coverage for weekly/session pacing thresholds, ignore windows, capped utilization, daily budget, and today's usage baseline behavior.
- Validation: `swift test` reaches test compilation and fails as expected because the Step 1.2/1.3 core symbols are not implemented yet (`PacingCalculator`, `PacingLabel`, `RecommendedAction`, `UsageSnapshot`).
