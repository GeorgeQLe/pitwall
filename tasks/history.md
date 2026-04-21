# History

## 2026-04-21

- Phase 2 Step 2.7 completed: ran the provider foundation green verification and confirmed Claude parsing, Codex/Gemini detection, provider confidence, secret-store, daily budget, and pacing tests all pass.
- Validation: `swift test` passes 29 XCTest cases with 0 failures and no warnings emitted.
- Phase 2 Step 2.6 completed: added `ProviderConfidenceMapper` with sanitized evidence inputs for Claude exact usage, Codex passive evidence, Gemini passive evidence, degraded telemetry fallback, and missing configuration states.
- Validation: `swift test --filter ProviderConfidenceTests` passes 5 confidence tests. Full `swift test` passes 29 XCTest cases with 0 failures and no warnings emitted.
- Phase 2 Step 2.5 completed: added `GeminiLocalDetector` for injected `LocalProviderFileSnapshot` evidence, reporting safe install/auth/activity booleans, sanitized settings metadata, and observed token counts without reading the real filesystem or serializing OAuth tokens or raw chat content.
- Validation: `swift build` passes. `swift test` and `swift test --filter ProviderDetectionTests` still fail as expected during the red phase because Step 2.6 has not implemented `ProviderConfidenceMapper`; SwiftPM compiles the confidence test file before running filtered tests.
- Phase 2 Step 2.4 completed: added injected `LocalProviderFileSnapshot` evidence helpers and a `CodexLocalDetector` that reports safe install/config/auth/activity/rate-limit booleans without reading the real filesystem or serializing auth tokens, prompts, stdout, source content, or raw session text.
- Validation: `swift build` passes. `swift test` progresses past Codex detector symbols and remains red as expected on later Phase 2 missing symbols (`GeminiLocalDetector` and `ProviderConfidenceMapper`).
- Phase 2 Step 2.3 completed: added `ProviderSecretKey`, async `ProviderSecretStore`, write-only `ProviderSecretState`, and an actor-backed `InMemorySecretStore` for injected tests without adding production Keychain calls.
- Adjusted secret-store XCTest assertions to await values before calling XCTest autoclosures, preserving the write-only public-state privacy check.
- Validation: `swift build` passes. `swift test` and `swift test --filter SecretStoreTests` both still fail as expected during the red phase because SwiftPM compiles all test files and later Phase 2 symbols are not implemented yet (`ProviderConfidenceMapper`, `LocalProviderFileSnapshot`, `CodexLocalDetector`, and `GeminiLocalDetector`).
- Phase 2 Step 2.2 completed: added Claude account/usage models, tolerant Claude usage parsing for known sections/null sections/unknown keys/extra usage, UTC reset parsing, and Claude auth/network error normalization into non-secret `ProviderState` values.
- Validation: `swift build` passes after allowing SwiftPM to write its compiler cache. `swift test` progresses past Claude parser tests and remains red as expected on later Phase 2 missing symbols (`InMemorySecretStore`, `ProviderSecretKey`, `ProviderSecretState`, `LocalProviderFileSnapshot`, `CodexLocalDetector`, `GeminiLocalDetector`, and `ProviderConfidenceMapper`).
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
