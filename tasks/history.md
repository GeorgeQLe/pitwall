# History

## 2026-04-21

- Phase 2 Step 2.1 completed: added red XCTest coverage for Claude usage parsing/error normalization, Codex and Gemini passive detection sanitization, provider confidence mapping, and write-only secret-store behavior, plus Claude JSON fixtures.
- Validation: `swift test` fails as expected for the red phase because Phase 2 implementation symbols do not exist yet (`ClaudeUsageParser`, `CodexLocalDetector`, `GeminiLocalDetector`, `ProviderConfidenceMapper`, `InMemorySecretStore`, and related models). No SwiftPM fixture warnings are emitted after declaring test resources.
- Phase 1 Step 1.6 completed: kept provider model public names stable, refactored pacing-window configuration into private calculator internals, and added explicit weekly ratio boundary tests for `0.50`, `0.85`, `1.15`, `1.50`, and `2.00`.
- Validation: baseline `swift test` passed 10 XCTest cases before edits; final `swift test` passes 11 XCTest cases with 0 failures and no warnings emitted.
- Phase 1 completed: all milestone acceptance criteria are satisfied, the completed phase was archived to `tasks/phases/phase-1.md`, and Phase 2 Provider Data Foundations was planned just-in-time in `tasks/todo.md` and `tasks/roadmap.md`.
- Phase 1 Step 1.5 completed: ran the core Swift test suite and verified all current Phase 1 pacing tests pass.
- Validation: `swift test` passes 10 XCTest cases with 0 failures and no warnings emitted.
- Phase 1 Step 1.4 completed: added a lightweight `PitwallCore` module anchor and updated `README.md` with the current SwiftPM target, `swift test` usage, and clean-room input rules for future app targets.
- Validation: `swift test` passes 10 XCTest cases with no warnings emitted.
- Phase 1 Step 1.3 completed: implemented `PacingCalculator` with deterministic weekly/session pace evaluation, ignore-window handling, capped/action mapping, daily budget calculation, and today's usage baseline behavior.
- Corrected daily-budget test fixtures so UTC calendar tests straddle an actual UTC local-midnight boundary while preserving coverage for exact, estimated, and unknown today-usage states.
- Validation: `swift test` passes 10 tests with no warnings emitted.
- Phase 1 Step 1.2 completed: added provider-agnostic core models for provider identity/status/confidence, pacing labels, recommendation actions, reset windows, usage snapshots, today's usage, pace evaluation, daily budget, normalized pacing state, provider actions, and provider-specific payload escape hatches.
- Validation: `swift test` builds the `PitwallCore` target with the new model layer and fails as expected because Step 1.3 has not implemented `PacingCalculator` yet.
- Phase 1 Step 1.1 completed: added a SwiftPM manifest, a red-phase `PitwallCore` target placeholder, and XCTest coverage for weekly/session pacing thresholds, ignore windows, capped utilization, daily budget, and today's usage baseline behavior.
- Validation: `swift test` reaches test compilation and fails as expected because the Step 1.2/1.3 core symbols are not implemented yet (`PacingCalculator`, `PacingLabel`, `RecommendedAction`, `UsageSnapshot`).
