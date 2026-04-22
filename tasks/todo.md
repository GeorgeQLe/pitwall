# Todo - Pitwall

> Current phase: 5 of 5 - Cross-Platform V1 Parity
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity planned just-in-time from completed Phase 4 boundaries.
- [ ] Ready for isolated agent-team execution of Phase 5 Step 5.1.

## Phase 5: Cross-Platform V1 Parity

> Test strategy: tests-after

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
- [ ] Step 5.1: Select and scaffold the cross-platform architecture
  - Files: modify `README.md`, create `docs/cross-platform-architecture.md`, modify `Package.swift` or create platform manifest files only after the selected approach is documented
  - Decide whether Pitwall remains SwiftPM-first with platform-specific shells or adds a separate cross-platform UI runtime; document the decision and trade-offs.
  - Preserve the existing macOS app and Phase 1-4 `PitwallCore`/`PitwallAppSupport` boundaries while making shared behavior reusable by Windows/Linux code.
  - Define how platform-specific tray/menu, notification, and credential-storage adapters plug into shared provider semantics without weakening privacy guarantees.
  - Implementation plan for next run:
    - This phase is `agent-team`; do not implement Step 5.1 in the shared local tree through a single `$run`.
    - Use Codex app worktrees or a dedicated Claude agent team with isolated branches/worktrees for the architecture, Windows shell, Linux shell, and security review lanes.
    - Start by reading `Package.swift`, `README.md`, `CLEAN_ROOM.md`, `specs/pitwall-macos-clean-room.md`, `specs/reproduction-checklist.md`, `Sources/PitwallCore/*`, and `Sources/PitwallAppSupport/*`.
    - Document the selected cross-platform approach in `docs/cross-platform-architecture.md` before adding platform scaffolding.
    - Validation for this planning/scaffold step depends on the selected approach, but macOS regression validation must still include `swift test` and `swift build`.
- [ ] Step 5.2: Extract shared behavior contracts for cross-platform reuse
  - Files: create `Sources/PitwallShared/*` or equivalent shared module files selected in Step 5.1, create `Tests/PitwallSharedTests/*`, modify `Package.swift`
  - Reuse Phase 1-4 behavior for pacing, Claude parsing, provider confidence, history retention, diagnostics redaction, notification policy, and GitHub heatmap request/response mapping.
  - Keep shared tests fixture-driven and free of live provider networks, live GitHub calls, real local provider files, or OS notification permission.
- [ ] Step 5.3: Implement Windows tray/menu parity against shared contracts
  - Files: create `Sources/PitwallWindows/*`, create `Tests/PitwallWindowsTests/*`, modify platform manifest/build files selected in Step 5.1
  - Implement tray/menu status, provider cards, settings, manual Claude credential flow, diagnostics export, optional GitHub heatmap display, and supported notification behavior.
  - Use Windows secure credential storage or document an explicit secure fallback before enabling saved Claude/GitHub tokens.
- [ ] Step 5.4: Implement Linux tray/menu parity against shared contracts
  - Files: create `Sources/PitwallLinux/*`, create `Tests/PitwallLinuxTests/*`, modify platform manifest/build files selected in Step 5.1
  - Implement tray/menu status, provider cards, settings, manual Claude credential flow, diagnostics export, optional GitHub heatmap display, and supported notification behavior.
  - Use Linux secure credential storage where available or document an explicit secure fallback before enabling saved Claude/GitHub tokens.
- [ ] Step 5.5: Add platform-specific Codex/Gemini passive detection adapters
  - Files: create platform adapter files under the Windows/Linux source directories selected in Step 5.1, create fixture tests under the matching platform test targets
  - Keep detection prompt/token safe on each supported platform by reading only allowed metadata, treating auth files as presence-only, and returning sanitized evidence.
  - Document platform path differences and unsupported metadata sources instead of silently broadening collection.

### Green
- [ ] Step 5.6: Write cross-platform regression tests covering acceptance criteria
  - Files: create or modify shared/platform test targets selected in Step 5.1
  - Cover Windows/Linux provider visibility, tray/menu formatting, credential write-only behavior, secure-storage fallback behavior, Codex/Gemini sanitization, diagnostics redaction, history retention, and GitHub heatmap parity.
- [ ] Step 5.7: Run platform validation and verify all supported builds/tests pass
  - Commands: platform-specific commands selected in Step 5.1 plus existing `swift test` and `swift build` for macOS regression coverage
  - Expected result: macOS remains green, shared tests pass, and each supported Windows/Linux build or documented platform limitation is explicit.
- [ ] Step 5.8: Refactor cross-platform boundaries if needed while keeping tests green
  - Files: modify shared/platform boundary files only as needed to clarify ownership without weakening coverage
  - Keep provider semantics shared, platform integrations isolated, and privacy constraints documented per platform.

### Milestone: Phase 5 Cross-Platform V1 Parity
**Acceptance Criteria:**
- [ ] Windows and Linux builds can run a tray/menu experience with Claude, Codex, and Gemini provider parity.
- [ ] Cross-platform implementations pass shared fixture/behavior tests for pacing, Claude parsing, provider confidence, history retention, and diagnostics redaction.
- [ ] Credential storage uses appropriate OS secure storage or an explicitly documented secure fallback.
- [ ] Codex/Gemini local detection remains prompt/token safe on each supported platform.
- [ ] GitHub heatmap behavior matches macOS v1 within platform constraints.
- [ ] Platform-specific differences are documented and do not silently weaken privacy guarantees.
- [ ] All phase tests pass
- [ ] No regressions in previous phase tests

**On Completion:**
- Deviations from plan: none recorded yet
- Tech debt / follow-ups: none recorded yet
- Ready for next phase: no
