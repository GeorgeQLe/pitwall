# Todo - Pitwall

> Current phase: 5 of 5 - Cross-Platform V1 Parity
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity planned just-in-time from completed Phase 4 boundaries.
- [x] Phase 5 Step 5.1 cross-platform architecture selected and documented.
- [x] Phase 5 Step 5.2 shared behavior contracts extracted into `PitwallShared`.
- [x] Phase 5 Step 5.3 Windows tray/menu parity shipped against `PitwallShared` contracts.
- [x] Phase 5 Step 5.4 Linux tray/menu parity shipped against `PitwallShared` contracts.
- [x] Phase 5 Step 5.5 platform-specific Codex/Gemini passive detection adapters shipped against `PitwallShared` / `PitwallCore` contracts.
- [x] Phase 5 Step 5.6 cross-platform regression tests landed against the 5.2 / 5.3 / 5.4 / 5.5 contracts.
- [ ] Ready for isolated agent-team execution of Phase 5 Step 5.7 (run platform validation and verify all supported builds/tests pass).

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
- [x] Step 5.1: Select and scaffold the cross-platform architecture
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
- [x] Step 5.2: Extract shared behavior contracts for cross-platform reuse
  - Files: create `Sources/PitwallShared/*`, create `Tests/PitwallSharedTests/*`, modify `Package.swift`, touch-up `Sources/PitwallAppSupport/*` only where strictly needed to conform to new protocols without changing macOS behavior.
  - Goal: introduce a `PitwallShared` SwiftPM target that holds cross-platform protocol contracts and pure logic from `PitwallAppSupport` that Windows/Linux shells will reuse in Steps 5.3/5.4, while keeping `PitwallCore` unchanged and `PitwallAppSupport` macOS-only for AppKit-bound code.
  - Architecture anchor: the chosen approach and adapter seams are documented in `docs/cross-platform-architecture.md`. Step 5.2 MUST honor that doc — do not re-litigate the decision. Protocols introduced here are the ones it promised: `ProviderConfigurationStorage`, `ProviderHistoryStorage`, `SettingsStorage` (and any notification-policy surface that is OS-agnostic).
  - Scope:
    - Add `PitwallShared` target to `Package.swift` (library, platforms: `.macOS(.v14)` plus allow Linux/Windows via `.when(platforms:)` where needed). Depend on `PitwallCore`. No dependency on `PitwallAppSupport`.
    - Define protocols in `Sources/PitwallShared/`:
      - `ProviderConfigurationStorage` — read/write non-secret provider configuration (replaces direct `FileManager` + `NSSearchPathForDirectoriesInDomains` use).
      - `ProviderHistoryStorage` — append/read retained history entries.
      - `SettingsStorage` — user preferences (display, pinning, pacing).
      - Keep them value-type-friendly and `Sendable` where reasonable. No `Foundation.URL` assumptions that are macOS-only; prefer `String` path/keys plus helper types so Windows/Linux can implement against `%APPDATA%` / XDG.
    - Extract pure policy/decision logic currently sitting in `PitwallAppSupport` that has no AppKit/UserNotifications dependency into `PitwallShared`. Candidates surfaced by 5.1: notification scheduling *policy* (not the macOS scheduler), provider state factory helpers, formatting helpers. Audit first; only move what is genuinely portable — do not drag `NSUserNotification`/AppKit-adjacent code across.
    - In `PitwallAppSupport`, replace direct storage calls with dependency-injected `PitwallShared` protocols. The existing macOS `FileManager` implementations become `AppSupportProviderConfigurationStorage`, etc., living alongside the AppKit shell (still in `PitwallAppSupport`). Behavior and on-disk layout MUST NOT change for macOS.
    - Fixture-driven shared tests in `Tests/PitwallSharedTests/`:
      - In-memory fakes for each protocol (mirror the pattern set by `InMemorySecretStore` in `PitwallCore`).
      - Round-trip tests: configuration write/read, history append/retention-window, settings persistence.
      - Policy tests for any moved notification policy (dedupe windows, quiet hours decision logic) using deterministic clock injection.
      - No live filesystem, no real provider sockets, no OS notification permission.
  - Test strategy: phase-level is `tests-after`, but this step lands its own shared-target tests alongside the extraction (the "Green" Step 5.6 covers *cross-platform regression* tests, not shared-target unit tests). Write fixture tests for every new protocol and every moved function.
  - Validation / acceptance:
    - `swift build` passes with the new target.
    - `swift test` passes all pre-existing 74 tests plus the new `PitwallSharedTests` cases. Zero macOS regressions.
    - `Sources/PitwallShared/` compiles without importing AppKit, UserNotifications, or any macOS-only framework. Grep check: no `import AppKit` / `import UserNotifications` in `PitwallShared`.
    - `Sources/PitwallAppSupport/` still builds and the macOS AppKit shell still behaves identically.
    - `Package.swift` keeps a single manifest (no per-platform manifest split).
  - Execution profile: phase is `agent-team`; only the `phase5-architecture-owner` lane owns the files touched here (`Package.swift`, `Sources/PitwallShared/*`, `Tests/PitwallSharedTests/*`). `Sources/PitwallAppSupport/*` is owned by other lanes' "must not edit" fence — the architecture lane may make the minimum conformance edits required here, but must record each such edit in the commit message so Steps 5.3/5.4 reviewers can see them. Dispatch one `Agent` call with `isolation: "worktree"`; no parallel lanes in this step. Integration, macOS regression (`swift build` + `swift test`), and task-doc updates run on the main agent exactly as in 5.1.
  - Known risks / gotchas:
    - `NSSearchPathForDirectoriesInDomains` is Foundation and works on Swift-on-Linux but returns different roots. The protocol must NOT leak macOS path semantics — design around injected roots, not hard-coded directory lookups inside the protocol.
    - Avoid importing `AppKit` transitively through helper types (e.g., do not move `NSImage`-adjacent formatters into `PitwallShared`).
    - Keep Codable/`JSONEncoder` use on the `Foundation` subset that's available cross-platform. Test that shared tests still pass with `--enable-test-discovery` (default).
    - Do not remove `PitwallAppSupport` symbols that `PitwallApp` depends on; re-export or keep thin shims where needed.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.2, (2) run `swift build` + `swift test` and confirm all tests pass, (3) mark Step 5.2 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.3 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.3 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.3. Do not call `ExitPlanMode` from normal mode. If `EnterPlanMode` is denied, stop and ask the user to explicitly run `/plan Step 5.3` instead of falling through.
- [x] Step 5.3: Implement Windows tray/menu parity against shared contracts
  - Files: create `Sources/PitwallWindows/*`, create `Tests/PitwallWindowsTests/*`, modify `Package.swift` to add the `PitwallWindows` target (gated via `.when(platforms: [.windows])` or equivalent condition so macOS builds ignore it), update `docs/cross-platform-architecture.md` only if the Windows shell discovers a concrete seam that is missing from the current doc.
  - Architecture anchor: the cross-platform architecture doc (`docs/cross-platform-architecture.md`) and the `PitwallShared` contracts shipped in Step 5.2 (`ProviderConfigurationStorage`, `ProviderHistoryStorage`, `SettingsStorage`, `NotificationScheduling`, `NotificationPolicy`, plus value types) are the binding contract. The Windows shell must consume these protocols; it must not reach into `PitwallCore` storage internals and must not depend on `PitwallAppSupport`.
  - Scope:
    - Add `PitwallWindows` target to `Package.swift`, dependency `["PitwallCore", "PitwallShared"]`, conditional for Windows only.
    - Implement Windows adapters against `PitwallShared` protocols:
      - File-backed `ProviderConfigurationStorage` / `ProviderHistoryStorage` / `SettingsStorage` writing JSON under `%APPDATA%\Pitwall\` (use injected root path; do not hard-code).
      - Windows `NotificationScheduling` adapter (toast notifications via `windows-rs`-equivalent or a documented fallback to no-op) behind the `PitwallShared` protocol so policy decisions stay shared.
      - `ProviderSecretStore` implementation backed by Windows Credential Manager (`CredReadW`/`CredWriteW`) or a documented secure fallback; must not log or render secrets.
    - Tray/menu + provider cards + settings surface + manual Claude credential flow + diagnostics export + optional GitHub heatmap display driven by `PitwallShared` and `PitwallCore` state only. UI framework choice (SwiftCrossUI, WinUI via interop, plain Win32 tray) is recorded in `docs/cross-platform-architecture.md` before coding.
    - Fixture tests in `Tests/PitwallWindowsTests/` — no live Credential Manager, no live filesystem outside a tmp dir, no live toast delivery.
  - Test strategy: tests-after phase, but ship unit tests for the Windows adapters' round-trip behavior and credential write-only contract alongside the adapters. Cross-platform regression coverage lands in Step 5.6.
  - Validation / acceptance:
    - `swift build` on macOS still passes (Windows target must not leak into macOS build graph).
    - `swift test` on macOS still passes all 84 pre-existing tests. Zero macOS regressions.
    - On a Windows host (or documented CI limitation), `swift build --triple x86_64-unknown-windows-msvc` (or the project's chosen Windows command) succeeds and `swift test` for `PitwallWindowsTests` passes.
    - Grep check: `Sources/PitwallWindows/` contains no `import AppKit` / `import UserNotifications` / `import PitwallAppSupport`.
  - Execution profile: phase is `agent-team`; only the `phase5-windows-shell` lane owns `Sources/PitwallWindows/*`, `Tests/PitwallWindowsTests/*`, and the Windows-specific docs. Lane must not edit `Sources/PitwallCore/*`, `Sources/PitwallApp/*`, `Sources/PitwallAppSupport/*`, `Sources/PitwallShared/*`, or `Sources/PitwallLinux/*`. Dispatch one `Agent` call with `isolation: "worktree"`.
  - Known risks / gotchas:
    - If the chosen Windows UI stack requires an additional SwiftPM or system dependency, record the dependency and licensing in `docs/cross-platform-architecture.md` before use.
    - `%APPDATA%` resolution differs between roaming and local profiles — design the storage adapter around an injected root directory, not an env lookup inside the protocol.
    - Credential Manager interop must fail closed: a failed save must not silently succeed, and a missing credential must return "not configured," never a degraded default that leaks state.
    - Do not import `Security.framework` symbols in Windows adapters; keep any Keychain code macOS-only via `#if canImport(Security)` fences.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.3, (2) run macOS `swift build` + `swift test` to confirm zero macOS regressions and the documented Windows validation command on a Windows host (or record the CI gap explicitly), (3) mark Step 5.3 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.4 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.4 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.4.
- [x] Step 5.4: Implement Linux tray/menu parity against shared contracts
  - Files: create `Sources/PitwallLinux/*`, create `Tests/PitwallLinuxTests/*`, modify `Package.swift` to add the `PitwallLinux` target (library, conditional equivalent so macOS builds ignore it — mirror the Step 5.3 treatment of `PitwallWindows`), update `docs/cross-platform-architecture.md` only if the Linux shell discovers a concrete seam that is missing from the current doc.
  - Architecture anchor: the cross-platform architecture doc (`docs/cross-platform-architecture.md`) plus the `PitwallShared` contracts shipped in Step 5.2 (`ProviderConfigurationStorage`, `ProviderHistoryStorage`, `SettingsStorage`, `NotificationScheduling`, `NotificationPolicy`, `UserPreferences`, `NotificationPreferences`) are the binding contract. The Linux shell consumes these protocols; it must not reach into `PitwallCore` storage internals and must not depend on `PitwallAppSupport` or `PitwallWindows`.
  - Scope:
    - Add `PitwallLinux` target to `Package.swift` with `dependencies: ["PitwallCore", "PitwallShared"]`, scoped so macOS builds ignore it (either `#if os(Linux)` source guards or a Swift-level `#if os(Linux)` toggle in `Package.swift`, matching the Step 5.3 decision).
    - Implement Linux adapters against `PitwallShared` protocols:
      - File-backed `ProviderConfigurationStorage`, `ProviderHistoryStorage`, `SettingsStorage` writing JSON under `$XDG_CONFIG_HOME/pitwall/` and `$XDG_DATA_HOME/pitwall/` with fallbacks to `~/.config/pitwall/` and `~/.local/share/pitwall/`. Use an injected root directory per storage role; do not read `XDG_*` env vars inside the protocol.
      - Linux `NotificationScheduling` adapter delivering via a narrow backend seam (`LinuxNotificationDelivering` or equivalent). Production wires `libnotify` / `org.freedesktop.Notifications` D-Bus; tests use a spy; a `LinuxNotificationSuppressedBackend` provides the documented fallback when the session bus is not reachable.
      - `ProviderSecretStore` implementation backed by `libsecret` / Secret Service via a narrow backend seam (`LinuxSecretServiceBackend` or equivalent). Production wires the Secret Service API; tests use an in-memory stub. Fails closed when the backend is unavailable: a `save` must throw (never silently degrade), and a missing credential must return `nil` (never a degraded default that leaks state). No plaintext file fallback.
    - Tray / menu + provider cards + settings surface + manual Claude credential flow + diagnostics export + optional GitHub heatmap display driven purely by `PitwallShared` + `PitwallCore` state. Ship the portable, AppKit-free view-model types first (mirror `WindowsStatusFormatter` / `WindowsTrayMenuBuilder` shape); `AppIndicator` / `libayatana-appindicator` binding glue and the "no tray available" fallback (for example, surfacing the popover as a windowed app) are recorded in `docs/cross-platform-architecture.md` in a "Linux Shell Stack (Step 5.4)" section before merge.
    - Fixture tests in `Tests/PitwallLinuxTests/` — no live Secret Service, no live D-Bus delivery, no filesystem outside a tmp dir. Cover: storage round-trip, history retention-window, settings round-trip, manual Claude credential flow (write-only contract, no secret rendered back), diagnostics export redaction, notification scheduler policy wiring, secret-store fail-closed behavior when backend is unavailable.
  - Test strategy: tests-after phase, but ship unit tests for the Linux adapters' round-trip behavior and credential write-only contract alongside the adapters. Cross-platform regression coverage lands in Step 5.6.
  - Validation / acceptance:
    - `swift build` on macOS still passes. `swift test` on macOS still passes all 112 pre-existing tests (84 from before Step 5.3 plus the 28 `PitwallWindowsTests`). Zero macOS regressions.
    - On a Linux host (or documented CI limitation), `swift build` + `swift test` for `PitwallLinuxTests` succeeds. Because the adapters are pure Foundation, macOS test runs may exercise `PitwallLinuxTests` as a portability proxy — if so, record that explicitly in `docs/cross-platform-architecture.md` exactly as Step 5.3 did for Windows.
    - Grep check: `Sources/PitwallLinux/` contains no `import AppKit` / `import UserNotifications` / `import Security` / `import PitwallAppSupport` / `import PitwallWindows`.
    - Linux secret-store fails closed: the backend-unavailable test asserts that `save` throws and `loadSecret` returns `nil`, never a degraded default.
  - Execution profile: phase is `agent-team`; only the `phase5-linux-shell` lane owns `Sources/PitwallLinux/*`, `Tests/PitwallLinuxTests/*`, and the Linux-specific docs. Lane must not edit `Sources/PitwallCore/*`, `Sources/PitwallApp/*`, `Sources/PitwallAppSupport/*`, `Sources/PitwallShared/*`, or `Sources/PitwallWindows/*`. Dispatch one `Agent` call with `isolation: "worktree"`.
  - Known risks / gotchas:
    - `libsecret` / Secret Service is not present on every Linux desktop environment. The fallback must be user-visible (for example, a "Secure storage unavailable — sign-in disabled" settings banner) and must refuse to persist Claude / GitHub tokens, not silently write them to a less-secure location.
    - Linux notifications may be unavailable in headless or container sessions; `LinuxNotificationSuppressedBackend` is the documented fallback and the scheduler must not raise a user-visible error when the session bus is missing.
    - XDG path resolution must honor env overrides (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`) but only at the shell boundary — the storage protocol takes an already-resolved root.
    - `ProviderSecretState.makePublicState` currently takes `some ProviderSecretStore`; when passing an `any ProviderSecretStore` existential, rely on Swift 5.7+ implicit existential opening exactly as the Windows Claude flow does. Keep `ProviderSecretStore` Sendable and PAT-free to preserve that.
    - Do not import `Security.framework` or WinRT symbols in Linux adapters; fence any macOS Keychain code behind `#if canImport(Security)` and any Windows Credential Manager code behind `#if os(Windows)` so nothing leaks into Linux builds.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.4, (2) run macOS `swift build` + `swift test` to confirm zero macOS regressions and the documented Linux validation command on a Linux host (or record the CI gap explicitly in `docs/cross-platform-architecture.md`), (3) mark Step 5.4 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.5 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.5 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.5. Do not call `ExitPlanMode` from normal mode. If `EnterPlanMode` is denied because an explicit user request is required, stop and ask the user to run `/plan Step 5.5` explicitly instead of falling through.
- [x] Step 5.5: Add platform-specific Codex/Gemini passive detection adapters
  - Files: create `Sources/PitwallWindows/WindowsCodexDetector.swift` + `Sources/PitwallWindows/WindowsGeminiDetector.swift`, create `Sources/PitwallLinux/LinuxCodexDetector.swift` + `Sources/PitwallLinux/LinuxGeminiDetector.swift`, create fixture tests under `Tests/PitwallWindowsTests/` and `Tests/PitwallLinuxTests/`; update `docs/cross-platform-architecture.md` with a "Codex/Gemini Passive Detection (Step 5.5)" section that records per-platform path maps and any unsupported metadata sources.
  - Architecture anchor: `PitwallCore` already defines the Codex/Gemini passive-detection contract (authoritative presence-only semantics, sanitized evidence, prompt-safe reads). Step 5.5 adds *platform-specific path resolvers and metadata readers* behind narrow backend seams on Windows and Linux. It must not reach into `PitwallCore` detector internals and must not depend on `PitwallAppSupport`; Linux must not depend on `PitwallWindows` and vice versa.
  - Scope:
    - Windows Codex detector — resolve `%APPDATA%\Codex\` (or the documented equivalent once confirmed) via an injected root, enumerate auth artifacts as presence-only booleans, read only size / mtime metadata, and return sanitized evidence to the shared detector contract. No file-content reads; no token bytes enter memory.
    - Windows Gemini detector — same shape against `%APPDATA%\Gemini\` (or the documented equivalent). Path resolution is injected, mirroring `WindowsStorageRoot`.
    - Linux Codex detector — resolve `$XDG_CONFIG_HOME/codex/` with `~/.config/codex/` fallback, presence-only reads, injected root, same sanitization rules.
    - Linux Gemini detector — resolve `$XDG_CONFIG_HOME/gemini/` with `~/.config/gemini/` fallback, same shape.
    - Narrow backend seams per detector (`WindowsCodexFilesystemProbing`, `LinuxCodexFilesystemProbing`, etc.) so tests inject a fixture probe; production wires the real filesystem reader. The probe must surface only allowed metadata (existence, size, mtime) — never raw bytes.
    - Per-platform suppressed fallback (`WindowsCodexSuppressedProbe` / `LinuxCodexSuppressedProbe`) for environments where the directory is inaccessible; the shell surfaces the degraded state, it does not fabricate evidence.
    - Fixture tests covering: presence-only contract (no file bytes leaked), sanitization (path redaction, no token-shaped substrings echoed back), injected-root usage (tests never touch real user home), and suppressed-probe fail-closed behavior.
  - Test strategy: tests-after phase, but ship unit tests alongside the adapters covering presence-only contract and sanitization. Cross-platform regression lands in Step 5.6.
  - Validation / acceptance:
    - `swift build` on macOS still passes. `swift test` on macOS still passes all 144 pre-existing tests (112 pre-5.4 + 32 `PitwallLinuxTests`). Zero macOS regressions.
    - On Windows / Linux hosts (or documented CI gap), platform builds and test suites pass. Because adapters stay pure Foundation, macOS runs exercise both suites as a portability proxy, mirroring 5.3 / 5.4.
    - Grep check: `Sources/PitwallWindows/`-new + `Sources/PitwallLinux/`-new detectors contain no `import AppKit` / `import UserNotifications` / `import Security` / `import PitwallAppSupport`; Linux detectors do not import `PitwallWindows` and vice versa.
    - Sanitization tests assert no token-shaped substring or full path appears in returned evidence.
  - Execution profile: phase is `agent-team`; the `phase5-windows-shell` and `phase5-linux-shell` lanes each own their respective detector files and tests. Dispatch two `Agent` calls with `isolation: "worktree"` (one per platform) that can run in parallel since they do not overlap on files. The main agent integrates.
  - Known risks / gotchas:
    - Do not read the *contents* of Codex / Gemini auth files. Treat them as presence-only. Anything beyond size/mtime must be surfaced to the main agent as a scope question before coding.
    - Path resolution on Linux must honor `XDG_CONFIG_HOME` env override only at the shell boundary; the detector protocol takes an already-resolved root (mirror `LinuxStorageRoot`).
    - Windows path on `%APPDATA%` vs. `%LOCALAPPDATA%` may differ between Codex/Gemini builds; record the final choice in `docs/cross-platform-architecture.md` before merge.
    - Do not import `Security.framework` or WinRT symbols in Linux adapters, and do not import `libsecret`-adjacent symbols in Windows adapters.
    - Detector evidence must sanitize absolute paths so diagnostics exports do not leak user home directories.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.5, (2) run macOS `swift build` + `swift test` to confirm zero macOS regressions and the documented Windows / Linux validation commands on platform hosts (or record the CI gap explicitly in `docs/cross-platform-architecture.md`), (3) mark Step 5.5 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.6 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.6 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.6. Do not call `ExitPlanMode` from normal mode. If `EnterPlanMode` is denied because an explicit user request is required, stop and ask the user to run `/plan Step 5.6` explicitly instead of falling through.

### Green
- [x] Step 5.6: Write cross-platform regression tests covering acceptance criteria
  - Files: add or extend regression test suites under `Tests/PitwallSharedTests/`, `Tests/PitwallWindowsTests/`, and `Tests/PitwallLinuxTests/` (no new source modules). Update `docs/cross-platform-architecture.md` with a "Cross-Platform Regression Coverage (Step 5.6)" section recording which acceptance bullets are covered by which suites and any gaps kept open for Step 5.7.
  - Architecture anchor: all contracts the regression suite asserts against already exist — `PitwallShared.NotificationPolicy`, `PitwallShared.ProviderConfiguration`, `PitwallShared.UserPreferences`, `PitwallCore` detector semantics, and the per-platform adapters shipped in 5.3 / 5.4 / 5.5. Step 5.6 adds *tests only*; it must not introduce new production code paths or reach into adapter internals beyond the public surfaces.
  - Scope:
    - Provider visibility parity: on each platform, `ProviderConfigurationStore` round-trips Claude/Codex/Gemini enablement and selection; disabled providers never appear in the tray view model. Assert Windows + Linux produce the same tray view-model shape for a shared input fixture.
    - Tray/menu formatting parity: reuse a shared `MenuBarStatusFormatter`-shaped fixture set and assert `WindowsStatusFormatter` + `LinuxStatusFormatter` emit byte-identical tooltips and card labels for each state.
    - Credential write-only behavior: assert `WindowsCredentialManagerSecretStore` and `LinuxSecretServiceStore` never surface a plaintext read path; failing backends return `nil` (reads) and throw `backendUnavailable` (writes). No degraded in-memory fallback.
    - Secure-storage fallback: assert the shell surfaces the "secure storage unavailable" banner path via a visible degraded state enum on both platforms (no silent persistence).
    - Codex/Gemini sanitization: reuse the fixture probes shipped in Step 5.5 and assert no absolute path, no token-shaped substring (`sk-…`, `ghp_…`, `ya29.…`, `AIza…`), and no file-content byte appears in the returned evidence on either platform.
    - Diagnostics redaction parity: assert `WindowsDiagnosticsExporter` and `LinuxDiagnosticsExporter` emit the same redacted key set for the same `DiagnosticsInput` fixture (via `DiagnosticsRedactor`).
    - History retention parity: assert `WindowsProviderHistoryStore` and `LinuxProviderHistoryStore` apply the same `ProviderHistoryRetention` windowing to a shared fixture.
    - GitHub heatmap parity: assert `GitHubHeatmapClient` produces identical `GitHubHeatmapModels` output on each platform for a recorded fixture.
  - Test strategy: tests-only phase. New suites live under the existing test targets — no new SwiftPM targets. Where a shared fixture exists in `Tests/PitwallCoreTests/Fixtures/`, prefer copying the reference into the platform test bundle (or promoting it into a new shared resources folder if needed) rather than duplicating bytes across suites.
  - Validation / acceptance:
    - `swift build` and `swift test` on macOS pass with the new suites added. Pre-existing test count (167) grows; zero regressions. Document the new total in `tasks/history.md` on commit.
    - On Windows / Linux hosts (or documented CI gap), platform builds and test suites pass. Because every adapter is pure Foundation, macOS `swift test` runs both platform suites as a portability proxy (mirroring the 5.3 / 5.4 / 5.5 precedent).
    - Grep check: new test files contain no `import AppKit` / `import UserNotifications` / `import Security` / `import PitwallAppSupport`; Linux tests do not import `PitwallWindows` and vice versa.
  - Execution profile: phase is `agent-team`; lanes `phase5-shared-regression`, `phase5-windows-regression`, and `phase5-linux-regression` can run in parallel with `isolation: "worktree"` since they don't overlap on files. The main agent integrates the final merge + doc update.
  - Known risks / gotchas:
    - Do not weaken existing sanitization tests by duplicating weaker variants. Use the strictest assertions (no absolute path, no token-shaped substring, no content bytes) on both platforms.
    - Do not let the regression suite become a macOS-only harness. Every new test must run on Windows + Linux hosts without a platform shim.
    - Fixture paths must be relative; tests must not reach into the user's real home directory — inject tmp roots exactly as the 5.3 / 5.4 / 5.5 suites do.
    - Do not introduce new production code in Step 5.6; if a test needs a new API surface, escalate to Step 5.8 ("refactor boundaries if needed") rather than quietly widening the adapter.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.6, (2) run macOS `swift build` + `swift test` to confirm zero macOS regressions and the documented Windows / Linux validation commands on platform hosts (or record the CI gap explicitly in `docs/cross-platform-architecture.md`), (3) mark Step 5.6 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.7 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.7 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.7. Do not call `ExitPlanMode` from normal mode. If `EnterPlanMode` is denied because an explicit user request is required, stop and ask the user to run `/plan Step 5.7` explicitly instead of falling through.
- [ ] Step 5.7: Run platform validation and verify all supported builds/tests pass
  - Files: update `docs/cross-platform-architecture.md` with a "Platform Validation (Step 5.7)" section recording the exact commands run, which platforms ran them (macOS only vs. real Windows / Linux hosts), pass/fail status, and any platform limitations that remain explicit for the Phase 5 milestone. No source or test code changes are in scope.
  - Architecture anchor: all validation targets (`PitwallCore`, `PitwallShared`, `PitwallAppSupport`, `PitwallWindows`, `PitwallLinux`, `PitwallApp`) already exist. Step 5.7 is a *verification* step, not an implementation step.
  - Scope:
    - Run `swift build` and `swift test` on macOS and record totals (expected: 193 tests, zero failures, zero regressions against Step 5.6's baseline).
    - Run `swift build --triple x86_64-unknown-windows-msvc` and `swift test` on a real Windows toolchain if one is available, else record the CI gap explicitly (matching the language used in 5.3 / 5.5).
    - Run `swift build` and `swift test` on a real Linux toolchain if one is available, else record the CI gap explicitly (matching 5.4 / 5.5).
    - Cross-check that each Phase 5 milestone acceptance bullet is satisfied by *at least one* Step 5.6 regression test and record the map in the architecture doc (or link back to the Step 5.6 "Cross-Platform Regression Coverage" section).
    - Explicitly call out what is *not* yet validated on real platform hosts (Win32 / WinRT / `libsecret` / `libnotify` / `libayatana-appindicator` bindings, production Credential Manager / Secret Service paths, tray / notification surfaces in a real desktop environment).
  - Test strategy: verification-only phase. No new tests are introduced; if a gap surfaces that requires additional coverage, escalate to Step 5.8 ("refactor boundaries if needed") rather than widening Step 5.7.
  - Validation / acceptance:
    - `swift build` and `swift test` on macOS pass with the Step 5.6 baseline preserved. Final test count recorded in `tasks/history.md`.
    - Windows / Linux platform validation results (pass, fail, or "CI gap recorded") are written into `docs/cross-platform-architecture.md` and `tasks/history.md` so reviewers can trace the phase milestone outcome.
    - The Phase 5 milestone acceptance checklist in `tasks/todo.md` is updated to reflect which bullets are verified on which platform and which are documented platform limitations.
  - Execution profile: phase is `agent-team`; lane `phase5-validation` runs alone on the main branch (no worktree needed — diff is limited to docs + history + todo).
  - Known risks / gotchas:
    - Do not silently widen or relax an acceptance bullet because the real platform binding is not yet wired. Document it as a limitation instead.
    - Do not introduce new source code in Step 5.7. If a validation attempt exposes a missing public surface, escalate to Step 5.8.
    - Do not repeat Step 5.6 coverage as Step 5.7 commentary — link to the "Cross-Platform Regression Coverage (Step 5.6)" section instead of duplicating the map.
  - Ship-one-step handoff contract: the clear-context implementation session must (1) implement only Step 5.7, (2) run macOS `swift build` + `swift test` to confirm zero regressions against the Step 5.6 baseline and the documented Windows / Linux validation commands on platform hosts (or record the CI gap explicitly in `docs/cross-platform-architecture.md`), (3) mark Step 5.7 done in `tasks/todo.md`, (4) update `tasks/history.md` with a session entry, (5) commit and push to `main` via `/commit-and-push-by-feature`, (6) skip deploy (no deploy contract exists), (7) write the Step 5.8 plan into `tasks/todo.md`, (8) ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, (9) start the approval UI for Step 5.8 by calling `EnterPlanMode` first, write a brief pass-through plan, then call `ExitPlanMode`, and (10) stop before implementing Step 5.8. Do not call `ExitPlanMode` from normal mode. If `EnterPlanMode` is denied because an explicit user request is required, stop and ask the user to run `/plan Step 5.8` explicitly instead of falling through.
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
