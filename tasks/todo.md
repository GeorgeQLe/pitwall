# Todo - Pitwall

> Current phase: 4 of 5 - V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap planned just-in-time from completed Phase 3 boundaries.
- [ ] Ready for `$run` to start Phase 4 Step 4.4.

## Phase 4: V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap

> Test strategy: tdd

**Goal:** Complete the macOS v1 feature set with durable local history, redacted diagnostics, configurable notifications, and optional GitHub contribution heatmap support.

**Scope:**
- Persist provider usage snapshots and apply the specified 24-hour/7-day retention and downsampling rules.
- Add session and weekly sparklines backed by derived snapshot data.
- Add local notifications for resets, expired auth, telemetry degradation, and user-configured pacing thresholds.
- Implement redacted diagnostics export.
- Add optional GitHub contribution heatmap with username/token configuration, Keychain token storage, GraphQL variable use, and hourly refresh limits.

**Acceptance Criteria:**
- History retention/downsampling tests cover last-24-hours retention, hourly downsampling, and seven-day expiry.
- Diagnostics export redacts cookies, tokens, auth headers, account ids when unnecessary, raw responses, prompts, and model responses.
- Notifications are user-configurable and do not fire when disabled.
- GitHub heatmap fetches the last 12 weeks through GraphQL variables and handles 401/403 as invalid token state.
- GitHub token storage uses Keychain and never renders the token back after saving.
- The reproduction checklist is substantially satisfied for the macOS v1 scope.

### Execution Profile
**Parallel mode:** review-only
**Integration owner:** main agent
**Conflict risk:** high
**Review gates:** correctness, tests, security, docs/API conformance, UX

**Subagent lanes:**
- Lane: phase4-privacy-review
  - Agent: explorer
  - Role: reviewer
  - Mode: review
  - Scope: Review history, diagnostics, notifications, and GitHub heatmap changes after implementation for privacy regressions, secret handling, clean-room scope, and acceptance-criteria coverage.
  - Depends on: Step 4.6
  - Deliverable: Review findings before final validation.

### Tests First
- [x] Step 4.1: Write failing tests for v1 hardening, history, diagnostics, notifications, and GitHub heatmap
  - Files: create `Tests/PitwallCoreTests/HistoryRetentionTests.swift`, create `Tests/PitwallCoreTests/DiagnosticsRedactionTests.swift`, create `Tests/PitwallCoreTests/GitHubHeatmapTests.swift`, create `Tests/PitwallAppSupportTests/NotificationPolicyTests.swift`, create `Tests/PitwallAppSupportTests/Phase4SettingsTests.swift`
  - Cover history retention/downsampling: keep all snapshots for the last 24 hours, downsample 24 hours to 7 days to one per hour, retain highest session utilization and latest weekly utilization per hourly bucket, and drop snapshots older than 7 days.
  - Cover derived-only history snapshots: provider/account ids, timestamps, confidence, session/weekly utilization, reset timestamps, and headline values only; no prompt text, token values, raw responses, cookies, or auth headers.
  - Cover diagnostics export redaction for cookies, tokens, auth headers, account ids when unnecessary, raw endpoint responses, prompts, and model responses while preserving provider status, confidence, last success timestamps, storage health, and redacted error summaries.
  - Cover notification policy behavior for reset, expired auth, telemetry degraded, and pacing-threshold events, including disabled notification preferences and injectable scheduler tests that do not require OS notification permission.
  - Cover GitHub heatmap behavior with injected transport: GraphQL variables instead of string interpolation, last-12-weeks response mapping, hourly refresh limiting with manual bypass, 401/403 invalid-token state, and Keychain-backed token state that never renders the saved token.
  - Cover settings persistence for history, diagnostics, notifications, and GitHub heatmap preferences without storing GitHub tokens in `UserDefaults`.
  - Tests MUST fail at this point because Phase 4 implementation symbols do not exist yet.
  - Implementation plan for next run:
    - Read `specs/pitwall-macos-clean-room.md` sections `Notifications`, `History`, `GitHub Heatmap`, `Diagnostics`, and `Verification`.
    - Read `specs/reproduction-checklist.md` to align tests with the remaining macOS v1 privacy and storage gates.
    - Read current patterns in `Tests/PitwallCoreTests/ProviderConfidenceTests.swift`, `Tests/PitwallCoreTests/ProviderDetectionTests.swift`, `Tests/PitwallAppSupportTests/ProviderRefreshCoordinatorTests.swift`, and `Tests/PitwallAppSupportTests/ProviderConfigurationStoreTests.swift`.
    - Add red-phase XCTest files only; do not implement production symbols in Step 4.1.
    - Use deterministic dates, injected transports/schedulers/stores, and synthetic provider states. Do not call GitHub, provider networks, Keychain, UserNotifications, or real local provider files.
    - Expected validation for this TDD step: `swift test` should fail because Phase 4 implementation symbols do not exist yet. Treat those failures as expected red-phase failures, but fix any unrelated syntax, fixture, or package-configuration problems before marking the step complete.

### Implementation
- [x] Step 4.2: Add durable provider history models and retention/downsampling
  - Files: create `Sources/PitwallCore/ProviderHistoryModels.swift`, create `Sources/PitwallCore/ProviderHistoryRetention.swift`, create `Sources/PitwallAppSupport/ProviderHistoryStore.swift`, modify `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift` only as needed to emit derived snapshots after refresh
  - Persist derived usage snapshots only: account id, timestamp, provider id, confidence, session/weekly utilization, reset timestamps, and headline values needed for sparklines/daily-budget calculations.
  - Implement 24-hour full retention, 24-hour-to-7-day hourly downsampling, highest session/latest weekly selection, and seven-day expiry with deterministic clock inputs.
  - Keep raw provider responses, prompt text, model responses, token values, stdout, source content, cookies, and auth headers out of history storage.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/HistoryRetentionTests.swift`, `Sources/PitwallCore/ProviderModels.swift`, `Sources/PitwallCore/ClaudeProviderModels.swift`, and `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift`.
    - Add `ProviderHistorySnapshot` in `PitwallCore` with only derived fields covered by the red tests: account id, recorded timestamp, provider id, confidence, optional session/weekly utilization, optional reset timestamps, and headline.
    - Add `ProviderHistoryRetention` in `PitwallCore` with deterministic `now`, full retention for snapshots newer than 24 hours, hourly buckets for 24 hours to 7 days, highest session/latest weekly merging inside each bucket, stable chronological output, and expiry after 7 days.
    - Add an app-support `ProviderHistoryStore` that persists encoded derived snapshots through injected storage/UserDefaults or app-support file storage without raw provider payloads or secrets.
    - Touch `ProviderRefreshCoordinator` only if needed to create and save derived snapshots from existing provider refresh outputs; do not broaden provider state with raw response content.
    - Validation: run `swift test`. During this step, failures in later Phase 4 red tests for diagnostics, notifications, settings, and GitHub heatmap are still expected; fix any history test failure, syntax issue, or unrelated regression before marking the step complete.
- [x] Step 4.3: Add diagnostics redaction and export support
  - Files: create `Sources/PitwallCore/DiagnosticsRedactor.swift`, create `Sources/PitwallAppSupport/DiagnosticsExporter.swift`, create `Sources/PitwallAppSupport/DiagnosticEventStore.swift`, modify `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift` only as needed to emit redacted diagnostic events
  - Export app/build metadata, enabled provider ids, provider status/confidence, redacted error states, last successful refresh timestamps, storage health, and recent diagnostic event summaries.
  - Redact cookies, tokens, auth headers, unnecessary account ids, raw responses, prompts, model responses, stdout, and source content before persistence or export.
  - Keep diagnostics local and avoid cloud upload, analytics, or hidden telemetry.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/DiagnosticsRedactionTests.swift`, `Sources/PitwallCore/ProviderModels.swift`, `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift`, and `specs/pitwall-macos-clean-room.md` diagnostics/privacy sections.
    - Add `DiagnosticEvent`, `StorageHealth`, `DiagnosticsExport`, `DiagnosticsExportBuilder`, and `DiagnosticsRedactor` in `PitwallCore`, keeping redaction pure and deterministic.
    - Redact secret-bearing keys and values before persistence/export: cookies, tokens, authorization headers, unnecessary account ids, raw responses, prompts, model responses, stdout, and source content.
    - Add `DiagnosticEventStore` in `PitwallAppSupport` with injected storage/UserDefaults or app-support file storage that stores only already-redacted diagnostic events.
    - Add `DiagnosticsExporter` in `PitwallAppSupport` to assemble app/build metadata, enabled provider ids, provider status/confidence, last successful refresh timestamps, storage health, and recent redacted diagnostic summaries.
    - Touch `ProviderRefreshCoordinator` only as needed to emit redacted diagnostic events for Claude auth/network failures and passive scan failures. Do not persist raw endpoint responses, prompts, stdout, source content, cookies, auth headers, or token values.
    - Validation: run `swift build` and `swift test`. During this step, later Phase 4 red tests for notifications, settings, and GitHub heatmap are still expected to fail; fix diagnostics test failures, syntax issues, and unrelated regressions before marking the step complete.
- [ ] Step 4.4: Add configurable local notification policy and scheduler abstraction
  - Files: create `Sources/PitwallAppSupport/NotificationPreferences.swift`, create `Sources/PitwallAppSupport/NotificationPolicy.swift`, create `Sources/PitwallAppSupport/NotificationScheduler.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/NotificationPreferencesView.swift`
  - Support Claude reset, expired auth, telemetry degraded, and pacing-threshold notification decisions through injectable schedulers.
  - Keep notifications user-configurable and ensure disabled preferences suppress all scheduling.
  - Avoid requiring live macOS notification permission for tests; concrete OS scheduling should be isolated behind the scheduler protocol.
  - Implementation plan for next run:
    - Read `Tests/PitwallAppSupportTests/NotificationPolicyTests.swift`, `Sources/PitwallAppSupport/UserPreferences.swift`, `Sources/PitwallApp/Views/SettingsView.swift`, and the notification/privacy sections of `specs/pitwall-macos-clean-room.md`.
    - Add `NotificationPreferences` in `PitwallAppSupport` with toggles for reset, expired auth, telemetry degraded, and pacing-threshold notifications plus a configurable `PacingLabel` threshold.
    - Add `NotificationEvent`, `NotificationRequest`, `NotificationScheduling`, and `NotificationPolicy` in `PitwallAppSupport`; keep decision logic deterministic and testable with an injected scheduler.
    - Add a concrete macOS notification scheduler behind the protocol without requiring live notification permission in tests.
    - Wire preferences into settings persistence only as needed for the Step 4.4 tests; avoid implementing GitHub heatmap settings in this step.
    - Add `NotificationPreferencesView` and connect it from `SettingsView` with native controls for notification toggles and threshold selection, keeping disabled preferences suppressing every schedule path.
    - Validation: run `swift build` and `swift test`. During this step, later Phase 4 red tests for settings gaps not covered by notifications and GitHub heatmap are still expected to fail; fix notification test failures, syntax issues, and unrelated regressions before marking the step complete.
- [ ] Step 4.5: Add optional GitHub heatmap configuration, token storage, and GraphQL fetch
  - Files: create `Sources/PitwallCore/GitHubHeatmapClient.swift`, create `Sources/PitwallCore/GitHubHeatmapModels.swift`, create `Sources/PitwallAppSupport/GitHubHeatmapSettings.swift`, create `Sources/PitwallAppSupport/GitHubHeatmapCoordinator.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/GitHubHeatmapSettingsView.swift`
  - Store the GitHub personal access token through `ProviderSecretStore`/Keychain and store username/non-secret heatmap settings outside Keychain.
  - Use GraphQL variables for username/date inputs, display the last 12 weeks, and enforce hourly refresh limits except for manual refresh.
  - Treat 401/403 as invalid or expired token state and never render saved tokens back into UI state.
- [ ] Step 4.6: Wire history, diagnostics, notifications, and heatmap into the macOS app surface
  - Files: modify `Sources/PitwallApp/MenuBarController.swift`, modify `Sources/PitwallApp/PopoverController.swift`, modify `Sources/PitwallApp/Views/PopoverContentView.swift`, modify `Sources/PitwallApp/Views/ProviderCardView.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/DiagnosticsExportView.swift`, create `Sources/PitwallApp/Views/GitHubHeatmapView.swift`, create `Sources/PitwallApp/Views/HistorySparklineView.swift`
  - Replace "History pending" placeholders with compact sparklines backed by derived snapshots when available.
  - Add settings controls for diagnostics export, notification preferences, and optional GitHub heatmap configuration.
  - Keep UI native macOS and restrained; no marketing screens, no raw diagnostic payload display, and no saved secret rendering.

### Green
- [ ] Step 4.7: Run Phase 4 tests and full regression validation
  - Commands: `swift test`, `swift build`
  - Expected result: all Phase 1-4 tests pass with no warnings emitted, and the app target builds for macOS 13+.
  - Fix unexpected failures before marking green.
- [ ] Step 4.8: Refactor v1 hardening boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/*History*.swift`, `Sources/PitwallCore/*Diagnostics*.swift`, `Sources/PitwallCore/*GitHub*.swift`, `Sources/PitwallAppSupport/*History*.swift`, `Sources/PitwallAppSupport/*Diagnostics*.swift`, `Sources/PitwallAppSupport/*Notification*.swift`, `Sources/PitwallAppSupport/*GitHub*.swift`, `Sources/PitwallApp/Views/*`, and tests only as needed to clarify behavior without weakening coverage
  - Keep pure retention/redaction/GraphQL request logic in `PitwallCore`, app coordination and persistence in `PitwallAppSupport`, and SwiftUI/AppKit presentation in `PitwallApp`.
  - Preserve clean-room constraints, local-only diagnostics, secret privacy, and honest confidence labels.
  - Validation: `swift test` and `swift build` must pass with no warnings emitted.

### Milestone: Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap
**Acceptance Criteria:**
- [ ] History retention/downsampling tests cover last-24-hours retention, hourly downsampling, and seven-day expiry.
- [ ] Diagnostics export redacts cookies, tokens, auth headers, account ids when unnecessary, raw responses, prompts, and model responses.
- [ ] Notifications are user-configurable and do not fire when disabled.
- [ ] GitHub heatmap fetches the last 12 weeks through GraphQL variables and handles 401/403 as invalid token state.
- [ ] GitHub token storage uses Keychain and never renders the token back after saving.
- [ ] The reproduction checklist is substantially satisfied for the macOS v1 scope.
- [ ] All phase tests pass
- [ ] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none recorded yet
- Tech debt / follow-ups: none recorded yet
- Ready for next phase: no
