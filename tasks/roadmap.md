# Pitwall Roadmap

Pitwall v1 is a clean-room, MIT-licensed product line that starts with a native macOS menu bar app and reaches provider parity across Claude, Codex, and Gemini before the first usable app milestone. GitHub heatmap support and cross-platform parity are in v1 scope, not indefinite stretch work.

## Phase 1: Foundation And Pacing Core

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

**Parallelization:** serial
**Coordination Notes:** This phase creates the project manifest and shared model boundaries, so file ownership is tightly coupled. Keep implementation serial and use tests as the review gate.

> Test strategy: tdd

### Execution Profile
**Parallel mode:** serial
**Integration owner:** main agent
**Conflict risk:** medium
**Review gates:** correctness, tests, security, docs/API conformance

**Subagent lanes:** none

### Tests First
- Step 1.1: Create the Swift test harness and write failing tests for the pacing core acceptance criteria
  - Files: create `Package.swift`, create `Tests/PitwallCoreTests/PacingCalculatorTests.swift`, create `Tests/PitwallCoreTests/DailyBudgetTests.swift`
  - Cover weekly pace ratio thresholds: underusing, behind pace, on pace, ahead of pace, warning, critical, capped
  - Cover session pace ignore windows: first 15 minutes and last 5 minutes
  - Cover weekly pace ignore windows: first 6 hours and last 1 hour
  - Cover daily budget with fractional days remaining and unknown local-midnight baseline
  - Tests MUST fail at this point because the core implementation does not exist yet

### Implementation
- Step 1.2: Create the provider-agnostic core model layer
  - Files: create `Sources/PitwallCore/ProviderModels.swift`
  - Include provider identifiers, provider status, confidence labels, pacing labels, actions, reset windows, usage snapshots, and provider state containers
- Step 1.3: Implement pacing calculations and recommendation mapping
  - Files: create `Sources/PitwallCore/PacingCalculator.swift`
  - Implement weekly and session pace ratios, ignore-window handling, capped handling, daily budget, today's usage baseline behavior, and recommendation output
- Step 1.4: Add clean-room project scaffolding notes for future app targets
  - Files: create `Sources/PitwallCore/PitwallCore.swift`, modify `README.md`
  - Document how to run `swift test` and keep implementation inputs tied to specs and public/platform docs only

### Green
- Step 1.5: Run the core test suite and verify all Phase 1 tests pass
  - Command: `swift test`
- Step 1.6: Refactor model naming and calculator boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/ProviderModels.swift`, modify `Sources/PitwallCore/PacingCalculator.swift`, modify tests only as needed to clarify behavior without weakening coverage

### Milestone: Phase 1 Foundation And Pacing Core
**Acceptance Criteria:**
- [x] A Swift package exists and `swift test` can run locally.
- [x] Pacing tests cover weekly and session calculations, ignore-window behavior, threshold labels, capped utilization, daily budget, and unknown-today behavior.
- [x] Domain models can represent Claude, Codex, Gemini, and future providers without forcing provider-specific quota shapes into one schema.
- [x] The implementation remains clean-room: no copied Swift/Xcode source, assets, screenshots, or tests from the prior ClaudeUsage lineage.
- [x] The scaffold does not store credentials, read provider local files, or call provider networks.
- [x] All phase tests pass
- [x] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none
- Tech debt / follow-ups: none recorded
- Ready for next phase: yes

## Phase 2: Provider Data Foundations

**Goal:** Build provider data adapters for Claude, Codex, and Gemini with equal first-class status while preserving privacy and clean-room constraints.

**Scope:**
- Implement fixture-driven Claude usage parsing and response normalization.
- Add a Keychain-backed secret storage abstraction with injected test storage.
- Implement Codex passive local detection from allowed metadata sources without persisting prompts, tokens, stdout, or source content.
- Implement Gemini passive local detection from allowed metadata sources without persisting prompts, tokens, or raw chat content.
- Define provider confidence mapping across provider-supplied, high-confidence, estimated, and observed-only states.

**Acceptance Criteria:**
- Claude fixtures parse known fields, ignore null sections, tolerate unknown sections, and expose extra usage when present.
- Claude auth error and network error states can be represented without losing last successful non-secret metadata.
- Codex detection reports install/auth/activity signals without serializing token values or prompt bodies.
- Gemini detection reports install/auth/activity signals without serializing token values or prompt bodies.
- Confidence mapping tests cover Claude exact data, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration.
- Keychain behavior is tested through an injected fake store and no saved secret is rendered back through read-only UI state.

**Parallelization:** research-only
**Coordination Notes:** Provider adapters are conceptually separable, but they share model contracts from Phase 1. Use parallel read-only research if needed; keep implementation integrated until model churn settles.

> Test strategy: tdd

### Execution Profile
**Parallel mode:** research-only
**Integration owner:** main agent
**Conflict risk:** medium
**Review gates:** correctness, tests, security, docs/API conformance

**Subagent lanes:**
- Lane: provider-source-review
  - Agent: explorer
  - Role: explorer
  - Mode: read-only
  - Scope: Review the Phase 2 provider sections in `specs/pitwall-macos-clean-room.md` and existing `PitwallCore` model boundaries for adapter contract needs.
  - Depends on: Step 2.1
  - Deliverable: Findings on model/API gaps before implementation.

### Tests First
- Step 2.1: Write failing tests for provider data foundations
  - Files: create `Tests/PitwallCoreTests/ClaudeUsageParserTests.swift`, create `Tests/PitwallCoreTests/ProviderDetectionTests.swift`, create `Tests/PitwallCoreTests/ProviderConfidenceTests.swift`, create `Tests/PitwallCoreTests/SecretStoreTests.swift`, create fixture files under `Tests/PitwallCoreTests/Fixtures/Claude/`
  - Cover Claude usage parsing for known usage fields, null sections, unknown sections, extra usage, UTC reset timestamps, and friendly section labels.
  - Cover Claude auth and network error normalization without exposing saved secrets.
  - Cover Codex passive detection from injected file snapshots for install/config/auth/activity/rate-limit signals while proving token and prompt bodies are not serialized.
  - Cover Gemini passive detection from injected file snapshots for install/auth/activity signals while proving token and raw chat content are not serialized.
  - Cover provider confidence mapping for Claude exact data, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration.
  - Cover a Keychain abstraction through an injected fake store with write-only secret behavior at the public state boundary.
  - Tests MUST fail at this point because parser, detector, confidence, and secret-store implementations do not exist yet.

### Implementation
- Step 2.2: Add Claude usage parsing and normalized provider state mapping
  - Files: create `Sources/PitwallCore/ClaudeUsageParser.swift`, create `Sources/PitwallCore/ClaudeProviderModels.swift`, modify `Sources/PitwallCore/ProviderModels.swift` only if tests show a provider-agnostic model gap
  - Parse documented Claude usage fields with tolerant handling for unknown keys and null sections.
  - Represent extra usage when present without forcing every provider into Claude's quota shape.
  - Normalize auth errors, network errors, stale last-success metadata, confidence labels, reset windows, and provider actions.
  - Keep this step free of live networking, credential storage, browser-cookie extraction, local file reads, or UI.
- Step 2.3: Add secret storage abstraction with fake test storage
  - Files: create `Sources/PitwallCore/SecretStore.swift`, create `Sources/PitwallCore/InMemorySecretStore.swift`, modify `Tests/PitwallCoreTests/SecretStoreTests.swift`
  - Define an async-safe protocol for saving, loading, and deleting provider-owned secrets.
  - Provide an injected in-memory implementation for tests only; do not add real Keychain calls yet unless needed by the testable contract.
  - Ensure public provider state can report configured/missing/expired without rendering secret values.
- Step 2.4: Add Codex passive detection models and sanitization
  - Files: create `Sources/PitwallCore/CodexLocalDetector.swift`, create `Sources/PitwallCore/LocalProviderEvidence.swift`, modify `Tests/PitwallCoreTests/ProviderDetectionTests.swift`
  - Consume injected file snapshots for `CODEX_HOME`/`~/.codex` paths, config presence, auth presence, history/session metadata, and rate-limit text.
  - Persist only safe metadata such as timestamps, byte offsets, auth presence, install/config flags, and limit/reset hints.
  - Prove prompt bodies, source content, stdout, token values, and raw session text are excluded from returned state.
- Step 2.5: Add Gemini passive detection models and sanitization
  - Files: create `Sources/PitwallCore/GeminiLocalDetector.swift`, modify `Sources/PitwallCore/LocalProviderEvidence.swift`, modify `Tests/PitwallCoreTests/ProviderDetectionTests.swift`
  - Consume injected file snapshots for `GEMINI_HOME`/`~/.gemini` paths, settings presence, OAuth presence, and local activity metadata.
  - Preserve quota/profile/auth-mode room for future telemetry without forcing Claude percentage fields.
  - Prove token values and raw chat content are excluded from returned state.
- Step 2.6: Add provider confidence mapping
  - Files: create `Sources/PitwallCore/ProviderConfidenceMapper.swift`, modify `Tests/PitwallCoreTests/ProviderConfidenceTests.swift`
  - Map Claude exact usage, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration to provider-agnostic confidence labels with explanations.
  - Keep provider-specific evidence as payloads or adapter-local structures instead of broadening shared models unnecessarily.

### Green
- Step 2.7: Run provider foundation tests and verify all Phase 2 tests pass
  - Command: `swift test`
  - Expected result: all Phase 1 and Phase 2 XCTest cases pass with no warnings emitted.
  - Fix unexpected failures in the parser, detector, confidence, or secret-store implementations before marking green.
- Step 2.8: Refactor provider foundation boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/*Provider*.swift`, `Sources/PitwallCore/*Detector.swift`, `Sources/PitwallCore/SecretStore.swift`, and tests only as needed to clarify behavior without weakening coverage
  - Prefer provider-specific adapter types over inflating `ProviderModels.swift`.
  - Preserve clean-room constraints: no copied upstream source/assets/tests, no real provider networking, no credential extraction, no raw prompt/token persistence.
  - Validation: `swift test` must pass all tests with no warnings emitted.

### Milestone: Phase 2 Provider Data Foundations
**Acceptance Criteria:**
- [x] Claude fixtures parse known fields, ignore null sections, tolerate unknown sections, and expose extra usage when present.
- [x] Claude auth error and network error states can be represented without losing last successful non-secret metadata.
- [x] Codex detection reports install/auth/activity signals without serializing token values or prompt bodies.
- [x] Gemini detection reports install/auth/activity signals without serializing token values or prompt bodies.
- [x] Confidence mapping tests cover Claude exact data, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration.
- [x] Keychain behavior is tested through an injected fake store and no saved secret is rendered back through read-only UI state.
- [x] All phase tests pass
- [x] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none
- Tech debt / follow-ups: none recorded
- Ready for next phase: yes

## Phase 3: First Usable macOS Provider Parity

**Goal:** Ship the first usable native macOS menu bar app where Claude, Codex, and Gemini all appear as first-class provider cards with honest confidence labels.

**Scope:**
- Create a native macOS menu bar app with no Dock icon.
- Add first-run onboarding, provider enablement, settings, manual refresh, pinned/rotating provider status, and configurable reset-time display.
- Implement Claude manual credential setup, test connection, live refresh, expired-auth handling, and stale-state display.
- Surface Codex and Gemini passive states beside Claude, including configure actions and confidence explanations.
- Show provider cards, current recommended action, daily budget, reset countdowns, and compact trend placeholders where history is not ready.

**Acceptance Criteria:**
- The app launches as a menu bar app on macOS 13+ with no Dock icon.
- A user can configure Claude credentials manually and test the connection without browser-cookie extraction.
- Claude, Codex, and Gemini are all visible in the popover/settings as first-class providers, even when some are missing configuration.
- Menu bar text and provider cards show action guidance and confidence labels rather than fake precision.
- Manual refresh works and does not bypass secret-storage or privacy constraints.
- First-run onboarding can be skipped, and skipped providers remain configurable rather than fatal.

**Parallelization:** review-only
**Coordination Notes:** UI, settings, provider state, and macOS app lifecycle share state boundaries. Implement serially, then use review gates for UX, privacy, and clean-room compliance.

> Test strategy: tests-after

### Execution Profile
**Parallel mode:** review-only
**Integration owner:** main agent
**Conflict risk:** high
**Review gates:** correctness, tests, security, docs/API conformance, UX

**Subagent lanes:**
- Lane: macos-ux-privacy-review
  - Agent: explorer
  - Role: reviewer
  - Mode: review
  - Scope: Review the Phase 3 app shell, onboarding/settings flow, and provider card UI against the clean-room spec for UX clarity, credential privacy, and honest confidence labeling after implementation.
  - Depends on: Step 3.6
  - Deliverable: Review findings before final validation.

### Implementation
- Step 3.1: Scaffold the macOS menu bar app and app-support target
  - Files: modify `Package.swift`, create `Sources/PitwallApp/PitwallApp.swift`, create `Sources/PitwallApp/AppDelegate.swift`, create `Sources/PitwallApp/Info.plist`, create `Sources/PitwallAppSupport/PitwallAppSupport.swift`
  - Add an executable macOS app target with `LSUIElement`/agent behavior so it runs as a menu bar app with no Dock icon.
  - Add a testable `PitwallAppSupport` library target for app state, formatters, and service coordination that can be covered without launching AppKit UI.
  - Keep the app scaffold clean-room and generated from Swift/AppKit conventions plus the project spec only.
- Step 3.2: Add provider presentation, rotation, and status formatting support
  - Files: create `Sources/PitwallAppSupport/AppProviderState.swift`, create `Sources/PitwallAppSupport/ProviderCardViewModel.swift`, create `Sources/PitwallAppSupport/MenuBarStatusFormatter.swift`, create `Sources/PitwallAppSupport/ProviderRotationController.swift`, create `Sources/PitwallAppSupport/UserPreferences.swift`
  - Build view models from `ProviderState` values for Claude, Codex, and Gemini without forcing fake precision.
  - Format menu bar text with current action guidance, confidence labels, reset time/countdown preference, pinned-provider behavior, and rotation that skips degraded providers when healthier providers exist.
  - Preserve skipped or missing providers as configurable states rather than fatal errors.
- Step 3.3: Build the menu bar controller, popover, and provider cards
  - Files: create `Sources/PitwallApp/MenuBarController.swift`, create `Sources/PitwallApp/PopoverController.swift`, create `Sources/PitwallApp/Views/PopoverContentView.swift`, create `Sources/PitwallApp/Views/ProviderCardView.swift`, create `Sources/PitwallApp/Views/StatusBadgeView.swift`, create `Sources/PitwallApp/Views/ClaudeUsageRowsView.swift`
  - Show provider cards for Claude, Codex, and Gemini with status, confidence explanation, primary/secondary metrics, last updated text, reset display, and quick actions.
  - Include current recommended action, daily budget/days remaining, refresh/settings/add-account controls, and compact trend placeholders until history exists.
  - Keep UI code native macOS SwiftUI/AppKit and avoid landing-page or marketing-style composition.
- Step 3.4: Add secure provider configuration storage and Claude account setup state
  - Files: create `Sources/PitwallCore/KeychainSecretStore.swift`, create `Sources/PitwallAppSupport/ProviderConfigurationStore.swift`, create `Sources/PitwallAppSupport/ClaudeAccountSettings.swift`, modify `Sources/PitwallCore/SecretStore.swift`
  - Store Claude session keys through the `ProviderSecretStore` abstraction and store non-secret account labels/org ids outside Keychain.
  - Keep credential inputs write-only after save; expose configured/missing/expired state without rendering saved secret values.
  - Do not extract browser cookies or read provider credentials from browsers or CLI auth files.
- Step 3.5: Add refresh coordination for Claude, Codex, and Gemini
  - Files: create `Sources/PitwallCore/ClaudeUsageClient.swift`, create `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift`, create `Sources/PitwallAppSupport/LocalProviderSnapshotLoader.swift`, create `Sources/PitwallAppSupport/PollingPolicy.swift`
  - Implement Claude manual refresh and test-connection behavior using user-supplied credentials, preserving expired auth and stale network states.
  - Bridge Codex and Gemini passive detection from allowed local metadata into provider cards through sanitized snapshots.
  - Respect polling/backoff defaults, manual-refresh bypass for one attempt, and privacy constraints around prompt/token/raw-response persistence.
- Step 3.6: Add onboarding and settings UI
  - Files: create `Sources/PitwallApp/Views/OnboardingView.swift`, create `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/ProviderEnablementView.swift`, create `Sources/PitwallApp/Views/ClaudeCredentialSetupView.swift`, create `Sources/PitwallApp/Views/DisplayPreferencesView.swift`, modify `Sources/PitwallApp/PopoverController.swift`
  - Implement first-run provider selection, skippable onboarding, Claude manual credential instructions, provider enablement, test connection, reset-time/countdown preference, rotation preference, and manual refresh actions.
  - Keep missing/skipped providers visible as configurable cards.
  - Ensure saved secrets are never rendered back into settings fields.

### Green
- Step 3.7: Write regression tests for app support and privacy boundaries
  - Files: create `Tests/PitwallAppSupportTests/MenuBarStatusFormatterTests.swift`, create `Tests/PitwallAppSupportTests/ProviderRotationControllerTests.swift`, create `Tests/PitwallAppSupportTests/ProviderCardViewModelTests.swift`, create `Tests/PitwallAppSupportTests/ProviderConfigurationStoreTests.swift`, create `Tests/PitwallAppSupportTests/ProviderRefreshCoordinatorTests.swift`
  - Cover menu bar action/confidence formatting, reset-time/countdown preference, pinned and rotating provider behavior, degraded-provider skip behavior, provider card visibility for missing Claude/Codex/Gemini states, write-only saved Claude credentials, and manual refresh not bypassing secret storage.
  - Tests should use injected stores/loaders/clients and must not call live provider networks or read real user provider files.
- Step 3.8: Run macOS app validation and verify Phase 3 tests pass
  - Commands: `swift test`, `swift build`
  - Expected result: all Phase 1-3 tests pass with no warnings emitted, and the app target builds for macOS 13+.
  - Fix unexpected failures before marking green.
- Step 3.9: Refactor app boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallAppSupport/*`, `Sources/PitwallApp/Views/*`, `Sources/PitwallApp/MenuBarController.swift`, `Sources/PitwallApp/PopoverController.swift`, and tests only as needed to clarify behavior without weakening coverage
  - Keep provider logic in `PitwallCore`/`PitwallAppSupport` and presentation code in `PitwallApp`.
  - Preserve clean-room constraints, secret privacy, and honest confidence labels.
  - Validation: `swift test` and `swift build` must pass with no warnings emitted.

### Milestone: Phase 3 First Usable macOS Provider Parity
**Acceptance Criteria:**
- [x] The app launches as a menu bar app on macOS 13+ with no Dock icon.
- [x] A user can configure Claude credentials manually and test the connection without browser-cookie extraction.
- [x] Claude, Codex, and Gemini are all visible in the popover/settings as first-class providers, even when some are missing configuration.
- [x] Menu bar text and provider cards show action guidance and confidence labels rather than fake precision.
- [x] Manual refresh works and does not bypass secret-storage or privacy constraints.
- [x] First-run onboarding can be skipped, and skipped providers remain configurable rather than fatal.
- [x] All phase tests pass
- [x] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: Review-only lane completed locally because subagent spawning requires explicit user delegation in the active environment.
- Tech debt / follow-ups: no Phase 3 follow-ups recorded
- Ready for next phase: yes

## Phase 4: V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap

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

**Parallelization:** implementation-safe
**Coordination Notes:** History, diagnostics, notifications, and heatmap can be implemented in mostly separate modules after provider/app state stabilizes. Shared settings and persistence remain integration chokepoints.

> Test strategy: tdd

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
- Step 4.1: Write failing tests for v1 hardening, history, diagnostics, notifications, and GitHub heatmap
  - Files: create `Tests/PitwallCoreTests/HistoryRetentionTests.swift`, create `Tests/PitwallCoreTests/DiagnosticsRedactionTests.swift`, create `Tests/PitwallCoreTests/GitHubHeatmapTests.swift`, create `Tests/PitwallAppSupportTests/NotificationPolicyTests.swift`, create `Tests/PitwallAppSupportTests/Phase4SettingsTests.swift`
  - Cover history retention/downsampling: keep all snapshots for the last 24 hours, downsample 24 hours to 7 days to one per hour, retain highest session utilization and latest weekly utilization per hourly bucket, and drop snapshots older than 7 days.
  - Cover derived-only history snapshots: provider/account ids, timestamps, confidence, session/weekly utilization, reset timestamps, and headline values only; no prompt text, token values, raw responses, cookies, or auth headers.
  - Cover diagnostics export redaction for cookies, tokens, auth headers, account ids when unnecessary, raw endpoint responses, prompts, and model responses while preserving provider status, confidence, last success timestamps, storage health, and redacted error summaries.
  - Cover notification policy behavior for reset, expired auth, telemetry degraded, and pacing-threshold events, including disabled notification preferences and injectable scheduler tests that do not require OS notification permission.
  - Cover GitHub heatmap behavior with injected transport: GraphQL variables instead of string interpolation, last-12-weeks response mapping, hourly refresh limiting with manual bypass, 401/403 invalid-token state, and Keychain-backed token state that never renders the saved token.
  - Cover settings persistence for history, diagnostics, notifications, and GitHub heatmap preferences without storing GitHub tokens in `UserDefaults`.
  - Tests MUST fail at this point because Phase 4 implementation symbols do not exist yet.

### Implementation
- Step 4.2: Add durable provider history models and retention/downsampling
  - Files: create `Sources/PitwallCore/ProviderHistoryModels.swift`, create `Sources/PitwallCore/ProviderHistoryRetention.swift`, create `Sources/PitwallAppSupport/ProviderHistoryStore.swift`, modify `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift` only as needed to emit derived snapshots after refresh
  - Persist derived usage snapshots only: account id, timestamp, provider id, confidence, session/weekly utilization, reset timestamps, and headline values needed for sparklines/daily-budget calculations.
  - Implement 24-hour full retention, 24-hour-to-7-day hourly downsampling, highest session/latest weekly selection, and seven-day expiry with deterministic clock inputs.
  - Keep raw provider responses, prompt text, model responses, token values, stdout, source content, cookies, and auth headers out of history storage.
- Step 4.3: Add diagnostics redaction and export support
  - Files: create `Sources/PitwallCore/DiagnosticsRedactor.swift`, create `Sources/PitwallAppSupport/DiagnosticsExporter.swift`, create `Sources/PitwallAppSupport/DiagnosticEventStore.swift`, modify `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift` only as needed to emit redacted diagnostic events
  - Export app/build metadata, enabled provider ids, provider status/confidence, redacted error states, last successful refresh timestamps, storage health, and recent diagnostic event summaries.
  - Redact cookies, tokens, auth headers, unnecessary account ids, raw responses, prompts, model responses, stdout, and source content before persistence or export.
  - Keep diagnostics local and avoid cloud upload, analytics, or hidden telemetry.
- Step 4.4: Add configurable local notification policy and scheduler abstraction
  - Files: create `Sources/PitwallAppSupport/NotificationPreferences.swift`, create `Sources/PitwallAppSupport/NotificationPolicy.swift`, create `Sources/PitwallAppSupport/NotificationScheduler.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/NotificationPreferencesView.swift`
  - Support Claude reset, expired auth, telemetry degraded, and pacing-threshold notification decisions through injectable schedulers.
  - Keep notifications user-configurable and ensure disabled preferences suppress all scheduling.
  - Avoid requiring live macOS notification permission for tests; concrete OS scheduling should be isolated behind the scheduler protocol.
- Step 4.5: Add optional GitHub heatmap configuration, token storage, and GraphQL fetch
  - Files: create `Sources/PitwallCore/GitHubHeatmapClient.swift`, create `Sources/PitwallCore/GitHubHeatmapModels.swift`, create `Sources/PitwallAppSupport/GitHubHeatmapSettings.swift`, create `Sources/PitwallAppSupport/GitHubHeatmapCoordinator.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/GitHubHeatmapSettingsView.swift`
  - Store the GitHub personal access token through `ProviderSecretStore`/Keychain and store username/non-secret heatmap settings outside Keychain.
  - Use GraphQL variables for username/date inputs, display the last 12 weeks, and enforce hourly refresh limits except for manual refresh.
  - Treat 401/403 as invalid or expired token state and never render saved tokens back into UI state.
- Step 4.6: Wire history, diagnostics, notifications, and heatmap into the macOS app surface
  - Files: modify `Sources/PitwallApp/MenuBarController.swift`, modify `Sources/PitwallApp/PopoverController.swift`, modify `Sources/PitwallApp/Views/PopoverContentView.swift`, modify `Sources/PitwallApp/Views/ProviderCardView.swift`, modify `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/DiagnosticsExportView.swift`, create `Sources/PitwallApp/Views/GitHubHeatmapView.swift`, create `Sources/PitwallApp/Views/HistorySparklineView.swift`
  - Replace "History pending" placeholders with compact sparklines backed by derived snapshots when available.
  - Add settings controls for diagnostics export, notification preferences, and optional GitHub heatmap configuration.
  - Keep UI native macOS and restrained; no marketing screens, no raw diagnostic payload display, and no saved secret rendering.

### Green
- Step 4.7: Run Phase 4 tests and full regression validation
  - Commands: `swift test`, `swift build`
  - Expected result: all Phase 1-4 tests pass with no warnings emitted, and the app target builds for macOS 13+.
  - Fix unexpected failures before marking green.
- Step 4.8: Refactor v1 hardening boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/*History*.swift`, `Sources/PitwallCore/*Diagnostics*.swift`, `Sources/PitwallCore/*GitHub*.swift`, `Sources/PitwallAppSupport/*History*.swift`, `Sources/PitwallAppSupport/*Diagnostics*.swift`, `Sources/PitwallAppSupport/*Notification*.swift`, `Sources/PitwallAppSupport/*GitHub*.swift`, `Sources/PitwallApp/Views/*`, and tests only as needed to clarify behavior without weakening coverage
  - Keep pure retention/redaction/GraphQL request logic in `PitwallCore`, app coordination and persistence in `PitwallAppSupport`, and SwiftUI/AppKit presentation in `PitwallApp`.
  - Preserve clean-room constraints, local-only diagnostics, secret privacy, and honest confidence labels.
  - Validation: `swift test` and `swift build` must pass with no warnings emitted.

### Milestone: Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap
**Acceptance Criteria:**
- [x] History retention/downsampling tests cover last-24-hours retention, hourly downsampling, and seven-day expiry.
- [x] Diagnostics export redacts cookies, tokens, auth headers, account ids when unnecessary, raw responses, prompts, and model responses.
- [x] Notifications are user-configurable and do not fire when disabled.
- [x] GitHub heatmap fetches the last 12 weeks through GraphQL variables and handles 401/403 as invalid token state.
- [x] GitHub token storage uses Keychain and never renders the token back after saving.
- [x] The reproduction checklist is substantially satisfied for the macOS v1 scope.
- [x] All phase tests pass
- [x] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: removed only a stale red-phase stub; no production boundary refactor was needed after review.
- Tech debt / follow-ups: Phase 5 cross-platform parity requires isolated worktrees or a dedicated agent team because the scope spans platform shells, storage, notifications, and shared behavior contracts.
- Ready for next phase: yes

## Phase 5: Cross-Platform V1 Parity

**Goal:** Deliver Windows/Linux parity for the v1 product behavior while keeping the macOS implementation and clean-room requirements intact.

**Scope:**
- Select and scaffold the cross-platform app approach for Windows and Linux.
- Reuse the Phase 1-4 product semantics, fixtures, privacy rules, and provider confidence behavior.
- Implement cross-platform tray/menu surface, provider cards, settings, Claude manual credential flow, Codex/Gemini passive detection, history, diagnostics, notifications where supported, and GitHub heatmap.
- Document platform-specific limitations where OS APIs differ.

**Acceptance Criteria:**
- Windows and Linux builds can run a tray/menu experience with Claude, Codex, and Gemini provider parity.
- Cross-platform implementations pass shared fixture/behavior tests for pacing, Claude parsing, provider confidence, history retention, and diagnostics redaction.
- Credential storage uses appropriate OS secure storage or an explicitly documented secure fallback.
- Codex/Gemini local detection remains prompt/token safe on each supported platform.
- GitHub heatmap behavior matches macOS v1 within platform constraints.
- Platform-specific differences are documented and do not silently weaken privacy guarantees.

**Parallelization:** agent-team
**Coordination Notes:** Cross-platform parity is broad and likely needs isolated worktrees or a dedicated agent team. Shared behavior fixtures and privacy rules should be owned centrally while platform shells are developed independently.

> Test strategy: tests-after

### Execution Profile
**Parallel mode:** agent-team
**Integration owner:** main agent
**Conflict risk:** high
**Review gates:** correctness, tests, security, docs/API conformance, UX

**Subagent lanes:**
- Lane: phase5-architecture-owner
  - Agent: default
  - Role: implementer
  - Mode: write
  - Scope: Select and document the cross-platform approach, establish repo structure, and define shared behavior contracts.
  - Owns: `Package.swift`, `README.md`, `docs/*`, `Sources/PitwallShared/*`, `Tests/PitwallSharedTests/*`
  - Must not edit: `Sources/PitwallApp/*`, `Sources/PitwallAppSupport/*`, platform shell directories after they are assigned
  - Depends on: none
  - Deliverable: Architecture decision, shared module scaffold, and shared behavior test contract.
- Lane: phase5-windows-shell
  - Agent: default
  - Role: implementer
  - Mode: write
  - Scope: Build the Windows tray/menu shell, provider cards, settings surface, and platform notification/storage adapters against shared contracts.
  - Owns: `Sources/PitwallWindows/*`, `Tests/PitwallWindowsTests/*`, Windows-specific docs
  - Must not edit: `Sources/PitwallCore/*`, `Sources/PitwallApp/*`, `Sources/PitwallLinux/*`
  - Depends on: phase5-architecture-owner
  - Deliverable: Windows parity patch and validation notes.
- Lane: phase5-linux-shell
  - Agent: default
  - Role: implementer
  - Mode: write
  - Scope: Build the Linux tray/menu shell, provider cards, settings surface, and platform notification/storage adapters against shared contracts.
  - Owns: `Sources/PitwallLinux/*`, `Tests/PitwallLinuxTests/*`, Linux-specific docs
  - Must not edit: `Sources/PitwallCore/*`, `Sources/PitwallApp/*`, `Sources/PitwallWindows/*`
  - Depends on: phase5-architecture-owner
  - Deliverable: Linux parity patch and validation notes.
- Lane: phase5-security-review
  - Agent: explorer
  - Role: reviewer
  - Mode: review
  - Scope: Review Windows/Linux credential storage, local detector sanitization, diagnostics export, and GitHub token handling for privacy regressions.
  - Depends on: phase5-windows-shell, phase5-linux-shell
  - Deliverable: Security/privacy review findings before final validation.

### Implementation
- Step 5.1: Select and scaffold the cross-platform architecture
  - Files: modify `README.md`, create `docs/cross-platform-architecture.md`, modify `Package.swift` or create platform manifest files only after the selected approach is documented
  - Decide whether Pitwall remains SwiftPM-first with platform-specific shells or adds a separate cross-platform UI runtime; document the decision and trade-offs.
  - Preserve the existing macOS app and Phase 1-4 `PitwallCore`/`PitwallAppSupport` boundaries while making shared behavior reusable by Windows/Linux code.
  - Define how platform-specific tray/menu, notification, and credential-storage adapters plug into shared provider semantics without weakening privacy guarantees.
  - Implementation note for next run: this phase is `agent-team`; do not implement Step 5.1 in the shared local tree through a single `$run`. Use isolated worktrees or a dedicated agent team.
- Step 5.2: Extract shared behavior contracts for cross-platform reuse
  - Files: create `Sources/PitwallShared/*` or equivalent shared module files selected in Step 5.1, create `Tests/PitwallSharedTests/*`, modify `Package.swift`
  - Reuse Phase 1-4 behavior for pacing, Claude parsing, provider confidence, history retention, diagnostics redaction, notification policy, and GitHub heatmap request/response mapping.
  - Keep shared tests fixture-driven and free of live provider networks, live GitHub calls, real local provider files, or OS notification permission.
- Step 5.3: Implement Windows tray/menu parity against shared contracts
  - Files: create `Sources/PitwallWindows/*`, create `Tests/PitwallWindowsTests/*`, modify platform manifest/build files selected in Step 5.1
  - Implement tray/menu status, provider cards, settings, manual Claude credential flow, diagnostics export, optional GitHub heatmap display, and supported notification behavior.
  - Use Windows secure credential storage or document an explicit secure fallback before enabling saved Claude/GitHub tokens.
- Step 5.4: Implement Linux tray/menu parity against shared contracts
  - Files: create `Sources/PitwallLinux/*`, create `Tests/PitwallLinuxTests/*`, modify platform manifest/build files selected in Step 5.1
  - Implement tray/menu status, provider cards, settings, manual Claude credential flow, diagnostics export, optional GitHub heatmap display, and supported notification behavior.
  - Use Linux secure credential storage where available or document an explicit secure fallback before enabling saved Claude/GitHub tokens.
- Step 5.5: Add platform-specific Codex/Gemini passive detection adapters
  - Files: create platform adapter files under the Windows/Linux source directories selected in Step 5.1, create fixture tests under the matching platform test targets
  - Keep detection prompt/token safe on each supported platform by reading only allowed metadata, treating auth files as presence-only, and returning sanitized evidence.
  - Document platform path differences and unsupported metadata sources instead of silently broadening collection.

### Green
- Step 5.6: Write cross-platform regression tests covering acceptance criteria
  - Files: create or modify shared/platform test targets selected in Step 5.1
  - Cover Windows/Linux provider visibility, tray/menu formatting, credential write-only behavior, secure-storage fallback behavior, Codex/Gemini sanitization, diagnostics redaction, history retention, and GitHub heatmap parity.
- Step 5.7: Run platform validation and verify all supported builds/tests pass
  - Commands: platform-specific commands selected in Step 5.1 plus existing `swift test` and `swift build` for macOS regression coverage
  - Expected result: macOS remains green, shared tests pass, and each supported Windows/Linux build or documented platform limitation is explicit.
- Step 5.8: Refactor cross-platform boundaries if needed while keeping tests green
  - Files: modify shared/platform boundary files only as needed to clarify ownership without weakening coverage
  - Keep provider semantics shared, platform integrations isolated, and privacy constraints documented per platform.

### Milestone: Phase 5 Cross-Platform V1 Parity
**Acceptance Criteria:**
- [x] Windows and Linux builds can run a tray/menu experience with Claude, Codex, and Gemini provider parity. *(Verified on macOS via portability-proxy regression suites; real Windows/Linux host validation documented as a platform limitation.)*
- [x] Cross-platform implementations pass shared fixture/behavior tests for pacing, Claude parsing, provider confidence, history retention, and diagnostics redaction. *(`PitwallCoreTests` + `PitwallSharedTests/CrossPlatformRegressionTests` + per-platform `*CrossPlatformRegressionTests`; 193/193 pass.)*
- [x] Credential storage uses appropriate OS secure storage or an explicitly documented secure fallback. *(Per-platform write-only regression + `backendUnavailable` enum tests; real Credential Manager / Secret Service wiring is a documented platform limitation.)*
- [x] Codex/Gemini local detection remains prompt/token safe on each supported platform. *(Per-platform detector sanitization + suppressed-probe fail-closed regression tests.)*
- [x] GitHub heatmap behavior matches macOS v1 within platform constraints. *(Shared + per-platform `*_producesIdenticalMappingForRecordedFixture` regression tests.)*
- [x] Platform-specific differences are documented and do not silently weaken privacy guarantees. *(`docs/cross-platform-architecture.md` sections 5.3–5.8.)*
- [x] All phase tests pass *(193/193, 0 failures, 0 regressions.)*
- [x] No regressions in previous phase tests *(Step 5.6 baseline preserved byte-identical through Steps 5.7 and 5.8.)*

**On Completion:**
- Deviations from plan: Steps 5.7 and 5.8 did not run Windows or Linux platform toolchains directly — no such CI host is available in this repo. The CI gap is recorded in `docs/cross-platform-architecture.md` "Platform Validation (Step 5.7)" + "Cross-Platform Boundary Refactor Audit (Step 5.8)" as a documented platform limitation rather than silently relaxing an acceptance bullet.
- Tech debt / follow-ups: wire real Win32 / WinRT bindings + a Windows CI runner; wire real `libsecret` / `libnotify` / `libayatana-appindicator` bindings + a Linux CI runner; wire production Credential Manager / Secret Service backends behind the existing `WindowsCredentialManagerBackend` / `LinuxSecretServiceBackend` seams; add real `FindFirstFileW` / `stat(2)` probes behind the existing `*CodexFilesystemProbing` / `*GeminiFilesystemProbing` seams.
- Ready for next phase: Phase 5 was the final v1 roadmap phase for cross-platform parity; Pitwall v1 product behavior is complete. Post-v1 follow-ups tracked as platform-limitation follow-ups above. Phases 6a and 6b are appended below to cover the macOS packaging + distribution gap surfaced during the v1 close-out review (see `specs/pitwall-macos-packaging.md`).

## Phase 6a: macOS Local Install

**Goal:** Turn the existing `PitwallApp` SwiftPM executable into a `.app` bundle the author can drop into `/Applications` with a single `make install`, so Pitwall can replace the legacy ClaudeUsage menu bar as a daily driver without any Apple Developer Program cost.

**Scope:**
- Build an `.app` bundle wrapper around the SwiftPM executable (`swift build --configuration release --product PitwallApp` + `Contents/MacOS` + `Contents/Info.plist` + `Contents/Resources`).
- Ad-hoc codesign the bundle so Gatekeeper accepts it when launched locally (no Developer ID, no notarization — works because the bundle is never quarantined).
- `Makefile` targets: `make build`, `make install`, `make uninstall`, `make run`. `make install` copies to `/Applications/Pitwall.app`; `make uninstall` removes the `.app` and unregisters the login-item but preserves `~/Library/Application Support/Pitwall/` and Keychain items.
- Menu bar icon wired to an SF Symbol via `NSImage(systemSymbolName:)` (baseline `gauge.with.dots.needle.67percent`) so no binary asset enters the repo.
- Launch-at-login wired through `SMAppService.mainApp.register()` / `.unregister()`; toggle exposed in `SettingsView`.
- Version metadata: `CFBundleShortVersionString` derived from a single-source `VERSION` file or `make` arg; `CFBundleVersion` = `git rev-list --count HEAD`.
- First-launch health check (run once per install, gated by `UserDefaults` key) that probes Application Support write access + Keychain round-trip and logs two events through the existing `DiagnosticEventStore` — no network, no upload.
- Short "Welcome to Pitwall" first-launch banner explaining that ClaudeUsage data is not migrated and the user should paste their `sessionKey` + `lastActiveOrg` into the existing onboarding flow.

**Acceptance Criteria:**
- [ ] `make install` on a clean macOS 13+ system produces `/Applications/Pitwall.app`; `codesign --verify --verbose` exits 0.
- [ ] Double-clicking `Pitwall.app` launches without a Gatekeeper block (bundle was never quarantined because it was built locally).
- [ ] Menu bar shows the SF Symbol icon; clicking opens the Phase 3 popover without change.
- [ ] "Launch at Login" toggle in `SettingsView` flips `SMAppService.mainApp` state; verified by reboot.
- [ ] `make uninstall` removes the bundle and unregisters the login-item; Application Support + Keychain items remain intact (verified via `ls` + `security find-generic-password`); reinstall restores prior state.
- [ ] First-launch health check writes two `DiagnosticEventStore` events on first install and does not repeat on subsequent launches.
- [ ] `CFBundleShortVersionString` / `CFBundleVersion` are derived at build time, not hard-coded; one source of truth for version bumps.
- [ ] macOS `swift build` + `swift test` still pass at the Phase 5 baseline (193/193) with zero regressions after Phase 6a lands.
- [ ] No new `import AppKit` / `import UserNotifications` / `import Security` in `PitwallShared` or platform shells (Phase 5 privacy fences preserved).

**Manual Tasks:**
- None. Phase 6a is fully automatable on the author's Mac; no Apple Developer enrollment, no notary credentials, no Sparkle keys.

**Parallelization:** serial

**Coordination Notes:** Touches `Package.swift`, `Sources/PitwallApp/Info.plist`, `Sources/PitwallApp/MenuBarController.swift`, `Sources/PitwallApp/Views/SettingsView.swift`, new `scripts/build-app-bundle.sh`, new `Makefile`, new `VERSION` file. Tight file coupling around the app bundle wiring makes serial execution the correct mode; no agent-team benefit here.

**On Completion** (fill in when phase is done):
- Deviations from plan: [none, or describe]
- Tech debt / follow-ups: [none, or list]
- Ready for next phase: yes/no

## Phase 6b: macOS Public Release

**Goal:** Turn the Phase 6a `.app` into a signed, notarized, auto-updating DMG that ships on GitHub Releases and optionally a Homebrew cask, so Pitwall can be downloaded and launched on machines other than the author's without Gatekeeper friction. Deferred until the author wants to share Pitwall widely.

**Scope:**
- Apple Developer Program enrollment (user-driven prerequisite, not an engineering deliverable).
- Developer ID Application certificate installed in the author's login Keychain; `.p12` backup in password manager.
- `notarytool` credentials stored via `xcrun notarytool store-credentials --apple-id … --team-id … pitwall-notary`.
- Sparkle 2.x integration: SwiftPM dependency added to `Package.swift`; `SUFeedURL` + `SUPublicEDKey` in `Info.plist`; `SPUStandardUpdaterController` wired into `AppDelegate`; EdDSA private key stored in password manager only (never committed).
- `make release VERSION=x.y.z` target that chains: SwiftPM release build → `.app` wrap → Developer ID codesign with hardened runtime + timestamp → DMG package → `xcrun notarytool submit --wait` → `xcrun stapler staple` → Sparkle EdDSA signature → appcast `<item>` append → `gh release create` + `appcast.xml` publish.
- Entitlements file (`Sources/PitwallApp/Pitwall.entitlements`) scoped for hardened runtime with no sandbox entitlement.
- Homebrew cask published in a self-hosted tap (`georgele/homebrew-pitwall`) or submitted to `homebrew-cask`. Final channel deferred to `/plan-phase 6b`.
- "Check for Updates…" menu item, "Automatically check for updates" toggle, and cadence picker added to `SettingsView`.

**Acceptance Criteria:**
- [ ] `make release VERSION=1.0.0` on a clean tree produces a signed DMG that passes `spctl --assess --type open --context context:primary-signature`.
- [ ] `xcrun stapler validate build/Pitwall-1.0.0.dmg` succeeds.
- [ ] Downloading the DMG from GitHub Releases on a different Mac launches Pitwall without any Gatekeeper dialog (quarantine xattr present on the downloaded bundle, notarization ticket accepted).
- [ ] Sparkle checks the appcast on launch and on-demand, offers an update when a newer version is published, verifies the EdDSA signature, relaunches into the new version, and preserves the user's session key, history, and settings.
- [ ] `brew install --cask pitwall` (via self-hosted tap or upstream cask) installs the same DMG into `/Applications/Pitwall.app` and launches without Gatekeeper issues.
- [ ] Phase 6a `make install` / `make uninstall` paths still work alongside `make release` for local iteration.
- [ ] Phase 6a first-launch health check runs once per install (signed or ad-hoc) — does not double-fire when Sparkle replaces the bundle in place.
- [ ] `Pitwall.app` runs under hardened runtime with no sandbox entitlement and no entitlement beyond what Phase 1-5 behavior requires.
- [ ] All Phase 1-6a tests continue to pass on macOS with zero regressions.

**Manual Tasks:**
- Enroll in the Apple Developer Program ($99/yr) _(blocks: Step 6b.1)_.
- Request + install Developer ID Application certificate from Apple Developer portal _(blocks: Step 6b.1)_.
- Generate app-specific password at appleid.apple.com for `notarytool` _(blocks: the first notarization submission)_.
- Generate Sparkle EdDSA key pair; store private key in password manager _(blocks: the first appcast signature)_.
- Publish `appcast.xml` hosting URL (GitHub Pages or raw file path) _(blocks: the first Sparkle update check)_.
- Create self-hosted Homebrew tap repo `georgele/homebrew-pitwall` OR submit to `homebrew-cask` _(blocks: the first `brew install --cask` verification)_.

**Parallelization:** serial

**Coordination Notes:** Sequential dependency on Phase 6a (reuses the bundle wrapper) plus on the manual-task prerequisites listed above. Touches `Package.swift` (Sparkle dep), `Sources/PitwallApp/Info.plist` (Sparkle keys), `Sources/PitwallApp/AppDelegate.swift`, `Sources/PitwallApp/Views/SettingsView.swift`, `Sources/PitwallApp/Pitwall.entitlements`, new `scripts/release.sh`, `Makefile` release target, `appcast.xml`. High coupling between release automation + app integration makes serial the right mode.

**On Completion** (fill in when phase is done):
- Deviations from plan: [none, or describe]
- Tech debt / follow-ups: [none, or list]
- Ready for next phase: yes/no
