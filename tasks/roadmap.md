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
