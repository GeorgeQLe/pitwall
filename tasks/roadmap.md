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
- [ ] The app launches as a menu bar app on macOS 13+ with no Dock icon.
- [ ] A user can configure Claude credentials manually and test the connection without browser-cookie extraction.
- [ ] Claude, Codex, and Gemini are all visible in the popover/settings as first-class providers, even when some are missing configuration.
- [ ] Menu bar text and provider cards show action guidance and confidence labels rather than fake precision.
- [ ] Manual refresh works and does not bypass secret-storage or privacy constraints.
- [ ] First-run onboarding can be skipped, and skipped providers remain configurable rather than fatal.
- [ ] All phase tests pass
- [ ] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none recorded yet
- Tech debt / follow-ups: none recorded yet
- Ready for next phase: no

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
