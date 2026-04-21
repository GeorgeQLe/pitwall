# Todo - Pitwall

> Current phase: 3 of 5 - First Usable macOS Provider Parity
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity planned just-in-time from completed Phase 2 boundaries.
- [x] Task pipeline is healthy; ready for `$run` to start Phase 3 Step 3.1.

## Phase 3: First Usable macOS Provider Parity

> Test strategy: tests-after

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
- [x] Step 3.1: Scaffold the macOS menu bar app and app-support target
  - Files: modify `Package.swift`, create `Sources/PitwallApp/PitwallApp.swift`, create `Sources/PitwallApp/AppDelegate.swift`, create `Sources/PitwallApp/Info.plist`, create `Sources/PitwallAppSupport/PitwallAppSupport.swift`
  - Add an executable macOS app target with `LSUIElement`/agent behavior so it runs as a menu bar app with no Dock icon.
  - Add a testable `PitwallAppSupport` library target for app state, formatters, and service coordination that can be covered without launching AppKit UI.
  - Keep the app scaffold clean-room and generated from Swift/AppKit conventions plus the project spec only.
  - Implementation plan for next run:
    - Read `Package.swift`, `README.md`, `Sources/PitwallCore/ProviderModels.swift`, and the `Menu Bar`, `Popover`, `Settings`, and `Onboarding` sections in `specs/pitwall-macos-clean-room.md`.
    - Modify `Package.swift` to add a `PitwallAppSupport` library target, a `PitwallApp` executable target, and a future `PitwallAppSupportTests` test target placeholder only if needed by SwiftPM.
    - Create `Sources/PitwallAppSupport/PitwallAppSupport.swift` as a small module anchor that imports `PitwallCore`.
    - Create `Sources/PitwallApp/PitwallApp.swift` and `Sources/PitwallApp/AppDelegate.swift` with a minimal AppKit/SwiftUI app lifecycle that initializes a menu bar item and suppresses the Dock icon.
    - Create `Sources/PitwallApp/Info.plist` with `LSUIElement` set for agent-style launch.
    - Keep this step free of provider networking, credential storage changes, real filesystem scans, and production UI complexity beyond a launchable menu bar shell.
    - Validation: `swift build` should compile the package; `swift test` should continue passing existing Phase 1-2 tests.
  - Completed notes:
    - Added SwiftPM `PitwallAppSupport` and `PitwallApp` targets.
    - Added a minimal AppKit status item shell with accessory activation policy and an `LSUIElement` plist kept for future app bundling.
    - SwiftPM excludes the plist from target resources because top-level `Info.plist` files are not supported as SwiftPM resource bundle contents.
    - Validation: `swift build` passes; `swift test` passes 29 XCTest cases with 0 failures and no warnings emitted.
- [ ] Step 3.2: Add provider presentation, rotation, and status formatting support
  - Files: create `Sources/PitwallAppSupport/AppProviderState.swift`, create `Sources/PitwallAppSupport/ProviderCardViewModel.swift`, create `Sources/PitwallAppSupport/MenuBarStatusFormatter.swift`, create `Sources/PitwallAppSupport/ProviderRotationController.swift`, create `Sources/PitwallAppSupport/UserPreferences.swift`
  - Build view models from `ProviderState` values for Claude, Codex, and Gemini without forcing fake precision.
  - Format menu bar text with current action guidance, confidence labels, reset time/countdown preference, pinned-provider behavior, and rotation that skips degraded providers when healthier providers exist.
  - Preserve skipped or missing providers as configurable states rather than fatal errors.
  - Implementation plan for future run:
    - Read the new app scaffold from Step 3.1 plus `Sources/PitwallCore/ProviderModels.swift` and `Sources/PitwallCore/PacingCalculator.swift`.
    - Define UI-facing provider card and menu bar status models in `PitwallAppSupport`, not `PitwallCore`, unless a provider-agnostic model gap is proven.
    - Add deterministic rotation logic with injectable clock/time inputs so tests can cover pinned provider, automatic rotation, pause, manual override, and degraded-provider skip behavior.
    - Keep display formatting honest: exact percentages only when present, confidence/status labels when exact data is absent, and configure/wait/conserve/switch action wording from existing core enums.
    - Validation: `swift build` should pass; run `swift test` if support logic is already covered by tests or if existing tests are affected.
- [ ] Step 3.3: Build the menu bar controller, popover, and provider cards
  - Files: create `Sources/PitwallApp/MenuBarController.swift`, create `Sources/PitwallApp/PopoverController.swift`, create `Sources/PitwallApp/Views/PopoverContentView.swift`, create `Sources/PitwallApp/Views/ProviderCardView.swift`, create `Sources/PitwallApp/Views/StatusBadgeView.swift`, create `Sources/PitwallApp/Views/ClaudeUsageRowsView.swift`
  - Show provider cards for Claude, Codex, and Gemini with status, confidence explanation, primary/secondary metrics, last updated text, reset display, and quick actions.
  - Include current recommended action, daily budget/days remaining, refresh/settings/add-account controls, and compact trend placeholders until history exists.
  - Keep UI code native macOS SwiftUI/AppKit and avoid landing-page or marketing-style composition.
  - Implementation plan for future run:
    - Read `Sources/PitwallAppSupport/*` from Step 3.2 and the spec's `Menu Bar` and `Popover` sections.
    - Wire `MenuBarController` to `NSStatusItem`, a popover controller, and menu actions for refresh, settings, pause rotation, provider selection, and quit.
    - Implement compact SwiftUI provider cards with stable sizing, plain confidence explanations, badges for stale/degraded/missing states, and quick actions.
    - Use existing provider state payloads for Claude usage rows and passive Codex/Gemini metadata without exposing raw tokens, prompts, stdout, source content, or raw session/chat text.
    - Validation: `swift build` should pass; defer regression tests to Step 3.7 unless a helper is risky enough to test immediately.
- [ ] Step 3.4: Add secure provider configuration storage and Claude account setup state
  - Files: create `Sources/PitwallCore/KeychainSecretStore.swift`, create `Sources/PitwallAppSupport/ProviderConfigurationStore.swift`, create `Sources/PitwallAppSupport/ClaudeAccountSettings.swift`, modify `Sources/PitwallCore/SecretStore.swift`
  - Store Claude session keys through the `ProviderSecretStore` abstraction and store non-secret account labels/org ids outside Keychain.
  - Keep credential inputs write-only after save; expose configured/missing/expired state without rendering saved secret values.
  - Do not extract browser cookies or read provider credentials from browsers or CLI auth files.
  - Implementation plan for future run:
    - Read `Sources/PitwallCore/SecretStore.swift`, `Sources/PitwallCore/InMemorySecretStore.swift`, `Tests/PitwallCoreTests/SecretStoreTests.swift`, and the spec's `Claude`, `Accounts`, `Secret Storage`, and `Settings` sections.
    - Add a macOS `KeychainSecretStore` implementation behind the existing `ProviderSecretStore` protocol, keeping the in-memory fake for tests.
    - Add an app-support configuration store for non-secret provider enablement, Claude account labels/org ids, display preferences, and provider plan/profile metadata.
    - Model Claude credential setup so saved session keys can be replaced or deleted but never rendered back into public state or UI fields.
    - Validation: `swift build` should pass; update or add tests in Step 3.7 to prove write-only behavior through app-support configuration state.
- [ ] Step 3.5: Add refresh coordination for Claude, Codex, and Gemini
  - Files: create `Sources/PitwallCore/ClaudeUsageClient.swift`, create `Sources/PitwallAppSupport/ProviderRefreshCoordinator.swift`, create `Sources/PitwallAppSupport/LocalProviderSnapshotLoader.swift`, create `Sources/PitwallAppSupport/PollingPolicy.swift`
  - Implement Claude manual refresh and test-connection behavior using user-supplied credentials, preserving expired auth and stale network states.
  - Bridge Codex and Gemini passive detection from allowed local metadata into provider cards through sanitized snapshots.
  - Respect polling/backoff defaults, manual-refresh bypass for one attempt, and privacy constraints around prompt/token/raw-response persistence.
  - Implementation plan for future run:
    - Read `Sources/PitwallCore/ClaudeUsageParser.swift`, `Sources/PitwallCore/CodexLocalDetector.swift`, `Sources/PitwallCore/GeminiLocalDetector.swift`, `Sources/PitwallCore/LocalProviderEvidence.swift`, and spec sections for `Claude`, `Polling`, `Codex`, and `Gemini`.
    - Add a small injectable Claude HTTP client that builds the documented request from user-provided session key/org id, parses success through `ClaudeUsageParser`, maps 401/403 to expired auth, and maps network failures to stale state with backoff.
    - Add an injectable local snapshot loader for Codex/Gemini allowed metadata paths; sanitize snapshots before detector calls and never persist raw prompt/token/chat/stdout/source content.
    - Add refresh coordination that supports manual refresh, test connection, passive scan cadence, telemetry degraded state after repeated failures, and one-attempt manual bypass of backoff.
    - Validation: `swift build` should pass; use injected clients/loaders in Step 3.7 tests rather than live network or real user files.
- [ ] Step 3.6: Add onboarding and settings UI
  - Files: create `Sources/PitwallApp/Views/OnboardingView.swift`, create `Sources/PitwallApp/Views/SettingsView.swift`, create `Sources/PitwallApp/Views/ProviderEnablementView.swift`, create `Sources/PitwallApp/Views/ClaudeCredentialSetupView.swift`, create `Sources/PitwallApp/Views/DisplayPreferencesView.swift`, modify `Sources/PitwallApp/PopoverController.swift`
  - Implement first-run provider selection, skippable onboarding, Claude manual credential instructions, provider enablement, test connection, reset-time/countdown preference, rotation preference, and manual refresh actions.
  - Keep missing/skipped providers visible as configurable cards.
  - Ensure saved secrets are never rendered back into settings fields.
  - Implementation plan for future run:
    - Read app-support configuration/refresh types from Steps 3.4-3.5 and spec sections for `Settings` and `Onboarding`.
    - Build native macOS settings and onboarding screens with controls for provider enablement, Claude manual credential setup, test connection, display preferences, polling interval, and rotation behavior.
    - Include the spec's Claude credential guidance in concise in-app setup copy while making clear the values are sensitive and stored locally.
    - Keep forms functional but restrained; avoid visible instructional text for generic UI mechanics, and reserve explanatory copy for credential/privacy requirements.
    - Validation: `swift build` should pass before review.

### Green
- [ ] Step 3.7: Write regression tests for app support and privacy boundaries
  - Files: create `Tests/PitwallAppSupportTests/MenuBarStatusFormatterTests.swift`, create `Tests/PitwallAppSupportTests/ProviderRotationControllerTests.swift`, create `Tests/PitwallAppSupportTests/ProviderCardViewModelTests.swift`, create `Tests/PitwallAppSupportTests/ProviderConfigurationStoreTests.swift`, create `Tests/PitwallAppSupportTests/ProviderRefreshCoordinatorTests.swift`
  - Cover menu bar action/confidence formatting, reset-time/countdown preference, pinned and rotating provider behavior, degraded-provider skip behavior, provider card visibility for missing Claude/Codex/Gemini states, write-only saved Claude credentials, and manual refresh not bypassing secret storage.
  - Tests should use injected stores/loaders/clients and must not call live provider networks or read real user provider files.
  - Implementation plan for future run:
    - Add `PitwallAppSupportTests` to `Package.swift` if Step 3.1 did not add it.
    - Write focused tests for the testable support target rather than screenshot/UI automation.
    - Use synthetic provider states, fake secret stores, fake Claude clients, fake local snapshot loaders, and deterministic clocks.
    - Validation: targeted app-support tests should fail only if implementation behavior is wrong; `swift test` should still avoid live networks and real provider files.
- [ ] Step 3.8: Run macOS app validation and verify Phase 3 tests pass
  - Commands: `swift test`, `swift build`
  - Expected result: all Phase 1-3 tests pass with no warnings emitted, and the app target builds for macOS 13+.
  - Fix unexpected failures before marking green.
  - Implementation plan for future run:
    - Run `swift test` and inspect output for warnings as well as failures.
    - Run `swift build` and inspect output for warnings as well as failures.
    - Fix any regressions in app support, provider privacy boundaries, app target compilation, or previous Phase 1-2 tests before marking this step complete.
- [ ] Step 3.9: Refactor app boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallAppSupport/*`, `Sources/PitwallApp/Views/*`, `Sources/PitwallApp/MenuBarController.swift`, `Sources/PitwallApp/PopoverController.swift`, and tests only as needed to clarify behavior without weakening coverage
  - Keep provider logic in `PitwallCore`/`PitwallAppSupport` and presentation code in `PitwallApp`.
  - Preserve clean-room constraints, secret privacy, and honest confidence labels.
  - Validation: `swift test` and `swift build` must pass with no warnings emitted.
  - Implementation plan for future run:
    - Audit whether UI-specific behavior leaked into `PitwallCore` or whether provider/networking behavior leaked into SwiftUI views.
    - Refactor only for concrete boundary, naming, or duplication improvements that preserve covered behavior.
    - Do not add Phase 4 features such as durable history, diagnostics export, notifications, or GitHub heatmap during this refactor.
    - If no refactor is needed, rerun validation and mark this step complete with "no code changes needed".

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
