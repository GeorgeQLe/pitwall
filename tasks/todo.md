# Todo - Pitwall

> Current phase: 2 of 5 - Provider Data Foundations
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Task pipeline is healthy; ready for `$run` to start Phase 2 Step 2.3.

## Phase 2: Provider Data Foundations

> Test strategy: tdd

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
- [x] Step 2.1: Write failing tests for provider data foundations
  - Files: create `Tests/PitwallCoreTests/ClaudeUsageParserTests.swift`, create `Tests/PitwallCoreTests/ProviderDetectionTests.swift`, create `Tests/PitwallCoreTests/ProviderConfidenceTests.swift`, create `Tests/PitwallCoreTests/SecretStoreTests.swift`, create fixture files under `Tests/PitwallCoreTests/Fixtures/Claude/`
  - Cover Claude usage parsing for known usage fields, null sections, unknown sections, extra usage, UTC reset timestamps, and friendly section labels.
  - Cover Claude auth and network error normalization without exposing saved secrets.
  - Cover Codex passive detection from injected file snapshots for install/config/auth/activity/rate-limit signals while proving token and prompt bodies are not serialized.
  - Cover Gemini passive detection from injected file snapshots for install/auth/activity signals while proving token and raw chat content are not serialized.
  - Cover provider confidence mapping for Claude exact data, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration.
  - Cover a Keychain abstraction through an injected fake store with write-only secret behavior at the public state boundary.
  - Tests MUST fail at this point because parser, detector, confidence, and secret-store implementations do not exist yet.
  - Implementation plan for next run:
    - Read `specs/pitwall-macos-clean-room.md` provider sections for Claude, Codex, Gemini, Accounts and Storage, and Verification.
    - Read existing Phase 1 sources in `Sources/PitwallCore/ProviderModels.swift` and `Sources/PitwallCore/PacingCalculator.swift` to reuse provider identifiers, confidence labels, status labels, actions, reset windows, and payload escape hatches.
    - Create fixtures under `Tests/PitwallCoreTests/Fixtures/Claude/` for a complete Claude usage response, a response with null known sections, a response with unknown sections, and a response with extra usage.
    - Create XCTest files listed above with expectations against public types that do not exist yet.
    - Keep red tests clean-room and privacy-focused: fixtures may include synthetic tokens/prompts only to assert they are not returned or serialized by future APIs.
    - Red-phase validation: `swift test` should compile the manifest and fail on missing Phase 2 implementation symbols.

### Implementation
- [x] Step 2.2: Add Claude usage parsing and normalized provider state mapping
  - Files: create `Sources/PitwallCore/ClaudeUsageParser.swift`, create `Sources/PitwallCore/ClaudeProviderModels.swift`, modify `Sources/PitwallCore/ProviderModels.swift` only if tests show a provider-agnostic model gap
  - Parse documented Claude usage fields with tolerant handling for unknown keys and null sections.
  - Represent extra usage when present without forcing every provider into Claude's quota shape.
  - Normalize auth errors, network errors, stale last-success metadata, confidence labels, reset windows, and provider actions.
  - Keep this step free of live networking, credential storage, browser-cookie extraction, local file reads, or UI.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/ClaudeUsageParserTests.swift`, `Tests/PitwallCoreTests/Fixtures/Claude/*.json`, and `specs/pitwall-macos-clean-room.md` `### Claude` before editing.
    - Create `Sources/PitwallCore/ClaudeProviderModels.swift` with Claude account metadata, parsed usage section, extra usage, usage snapshot, and error reason types needed by the tests.
    - Create `Sources/PitwallCore/ClaudeUsageParser.swift` with tolerant JSON decoding for known usage sections, unknown-section tracking, UTC ISO-8601 reset parsing, and extra-usage parsing.
    - Add Claude error normalization that returns `ProviderState` with expired/stale status, non-secret account metadata payloads, reset windows, and provider actions while never exposing session keys.
    - Do not implement Codex, Gemini, confidence mapper, or secret-store production types in this step except for unavoidable shared-model gaps proven by the Claude tests.
    - Validation: `swift test` should progress past Claude parser symbols while remaining red on later Phase 2 missing types until Steps 2.3-2.6 are implemented.
- [x] Step 2.3: Add secret storage abstraction with fake test storage
  - Files: create `Sources/PitwallCore/SecretStore.swift`, create `Sources/PitwallCore/InMemorySecretStore.swift`, modify `Tests/PitwallCoreTests/SecretStoreTests.swift`
  - Define an async-safe protocol for saving, loading, and deleting provider-owned secrets.
  - Provide an injected in-memory implementation for tests only; do not add real Keychain calls yet unless needed by the testable contract.
  - Ensure public provider state can report configured/missing/expired without rendering secret values.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/SecretStoreTests.swift`, `Sources/PitwallCore/ProviderModels.swift`, and `specs/pitwall-macos-clean-room.md` Accounts and Storage sections before editing.
    - Create `Sources/PitwallCore/SecretStore.swift` with `ProviderSecretKey`, `ProviderSecretStore`, public secret status/state types, and a `ProviderSecretState.makePublicState(...)` helper that checks configured/missing status without exposing saved values.
    - Create `Sources/PitwallCore/InMemorySecretStore.swift` with an actor-backed or otherwise async-safe fake store for tests.
    - Keep this step free of production Keychain calls, provider networking, UI, and any read-back surface that renders secret values.
    - Do not implement Codex, Gemini, or confidence mapper types in this step except for unavoidable compile support proven by the secret-store tests.
    - Validation: `swift test` should progress past secret-store symbols while remaining red on later Phase 2 missing detector/confidence types until Steps 2.4-2.6 are implemented.
- [x] Step 2.4: Add Codex passive detection models and sanitization
  - Files: create `Sources/PitwallCore/CodexLocalDetector.swift`, create `Sources/PitwallCore/LocalProviderEvidence.swift`, modify `Tests/PitwallCoreTests/ProviderDetectionTests.swift`
  - Consume injected file snapshots for `CODEX_HOME`/`~/.codex` paths, config presence, auth presence, history/session metadata, and rate-limit text.
  - Persist only safe metadata such as timestamps, byte offsets, auth presence, install/config flags, and limit/reset hints.
  - Prove prompt bodies, source content, stdout, token values, and raw session text are excluded from returned state.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/ProviderDetectionTests.swift` and the Codex sections in `specs/pitwall-macos-clean-room.md` before editing.
    - Create `Sources/PitwallCore/LocalProviderEvidence.swift` with `LocalProviderFileSnapshot` and small sanitized evidence helpers shared by Codex and future Gemini detection.
    - Create `Sources/PitwallCore/CodexLocalDetector.swift` with a detector that consumes injected file snapshots only; do not read the real filesystem, env vars, prompts, stdout, source content, or token values.
    - Treat `config.toml` presence as configuration evidence, `auth.json` presence as auth evidence without parsing/storing token fields, history/session file presence as activity evidence, and rate-limit log text as a limit signal without retaining raw log contents.
    - Return `ProviderState` values with safe payload booleans such as `installDetected`, `authDetected`, `activityDetected`, and `rateLimitDetected`; missing configuration should produce `.missingConfiguration`, `.observedOnly`, and a configure action.
    - Do not implement Gemini or provider confidence mapping in this step except for unavoidable shared local-evidence support.
    - Validation: `swift test` should progress past Codex detector symbols while remaining red on later Gemini/confidence missing types until Steps 2.5-2.6 are implemented.
- [ ] Step 2.5: Add Gemini passive detection models and sanitization
  - Files: create `Sources/PitwallCore/GeminiLocalDetector.swift`, modify `Sources/PitwallCore/LocalProviderEvidence.swift`, modify `Tests/PitwallCoreTests/ProviderDetectionTests.swift`
  - Consume injected file snapshots for `GEMINI_HOME`/`~/.gemini` paths, settings presence, OAuth presence, and local activity metadata.
  - Preserve quota/profile/auth-mode room for future telemetry without forcing Claude percentage fields.
  - Prove token values and raw chat content are excluded from returned state.
  - Implementation plan for next run:
    - Read `Tests/PitwallCoreTests/ProviderDetectionTests.swift`, `Sources/PitwallCore/LocalProviderEvidence.swift`, `Sources/PitwallCore/CodexLocalDetector.swift`, and the Gemini section in `specs/pitwall-macos-clean-room.md` before editing.
    - Extend `Sources/PitwallCore/LocalProviderEvidence.swift` only for shared sanitized helpers that Gemini also needs; do not add provider-specific Gemini behavior to the shared file unless it is genuinely reusable.
    - Create `Sources/PitwallCore/GeminiLocalDetector.swift` with a detector that consumes injected `LocalProviderFileSnapshot` values only; do not read the real filesystem, env vars, tokens, raw chats, stdout, source content, or provider credential files directly.
    - Treat `settings.json` presence as configuration/install evidence, OAuth credential file presence as auth evidence without parsing or storing token fields, and local chat/session file presence as activity evidence without retaining `raw_chat` or message bodies.
    - Return `ProviderState` values with safe payload booleans such as `installDetected`, `authDetected`, `activityDetected`, and any safe quota/profile metadata already expected by tests such as `tokenCountObserved`; missing configuration should produce `.missingConfiguration`, `.observedOnly`, and a configure action.
    - Preserve future room for Gemini auth-mode/profile/quota buckets through sanitized payloads or Gemini-local types rather than adding Claude-specific percentage assumptions to `ProviderModels.swift`.
    - Do not implement provider confidence mapping in this step except for unavoidable compile support proven by Gemini detector tests.
    - Validation: `swift test` should progress past Gemini detector symbols while remaining red on missing `ProviderConfidenceMapper` until Step 2.6 is implemented.
- [ ] Step 2.6: Add provider confidence mapping
  - Files: create `Sources/PitwallCore/ProviderConfidenceMapper.swift`, modify `Tests/PitwallCoreTests/ProviderConfidenceTests.swift`
  - Map Claude exact usage, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration to provider-agnostic confidence labels with explanations.
  - Keep provider-specific evidence as payloads or adapter-local structures instead of broadening shared models unnecessarily.

### Green
- [ ] Step 2.7: Run provider foundation tests and verify all Phase 2 tests pass
  - Command: `swift test`
  - Expected result: all Phase 1 and Phase 2 XCTest cases pass with no warnings emitted.
  - Fix unexpected failures in the parser, detector, confidence, or secret-store implementations before marking green.
- [ ] Step 2.8: Refactor provider foundation boundaries if needed while keeping tests green
  - Files: modify `Sources/PitwallCore/*Provider*.swift`, `Sources/PitwallCore/*Detector.swift`, `Sources/PitwallCore/SecretStore.swift`, and tests only as needed to clarify behavior without weakening coverage
  - Prefer provider-specific adapter types over inflating `ProviderModels.swift`.
  - Preserve clean-room constraints: no copied upstream source/assets/tests, no real provider networking, no credential extraction, no raw prompt/token persistence.
  - Validation: `swift test` must pass all tests with no warnings emitted.

### Milestone: Phase 2 Provider Data Foundations
**Acceptance Criteria:**
- [ ] Claude fixtures parse known fields, ignore null sections, tolerate unknown sections, and expose extra usage when present.
- [ ] Claude auth error and network error states can be represented without losing last successful non-secret metadata.
- [ ] Codex detection reports install/auth/activity signals without serializing token values or prompt bodies.
- [ ] Gemini detection reports install/auth/activity signals without serializing token values or prompt bodies.
- [ ] Confidence mapping tests cover Claude exact data, Codex passive states, Gemini passive states, degraded telemetry, and missing configuration.
- [ ] Keychain behavior is tested through an injected fake store and no saved secret is rendered back through read-only UI state.
- [ ] All phase tests pass
- [ ] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none recorded yet
- Tech debt / follow-ups: none recorded yet
- Ready for next phase: no
