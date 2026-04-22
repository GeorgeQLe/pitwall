# Todo - Pitwall

> Current phase: 6a of 6b — macOS Local Install (packaging phase, appended post-v1).
> Source roadmap: `tasks/roadmap.md`
> Project: Pitwall — clean-room macOS menu bar app for Claude/Codex/Gemini usage pacing.

## Priority Task Queue

- [x] `/run` — execute Phase 6a Step 6a.1 (VERSION file + version derivation helper). Completed 2026-04-22.
- [ ] `/run` — execute Phase 6a Step 6a.2 (`.app` bundle wrapper script + `Info.plist` placeholder substitution). Evidence: Step 6a.2 is fully decomposed below; reads `VERSION` (now on disk) and injects `CFBundleShortVersionString` + `CFBundleVersion` (from `git rev-list --count HEAD`) + `CFBundleExecutable` + `NSHumanReadableCopyright` into an expanded Info.plist; ad-hoc-signs `build/Pitwall.app`.
- [ ] After Phase 6a ships: `/plan-phase 6b` — Phase 6b is deferred until the author decides to share Pitwall publicly; blocked on Apple Developer enrollment ($99/yr) and Sparkle/notary credential setup. Do not plan 6b until 6a is complete and the user confirms intent to go public.

## Completed Phases

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity completed and archived to `tasks/phases/phase-5.md`.

## Phase 6a: macOS Local Install

> Test strategy: tests-after

**Goal:** Turn the existing `PitwallApp` SwiftPM executable into a `.app` bundle the author can drop into `/Applications` with a single `make install`, so Pitwall can replace the legacy ClaudeUsage menu bar as a daily driver without any Apple Developer Program cost.

**Scope:**
- Build an `.app` bundle wrapper around the SwiftPM executable (`swift build --configuration release --product PitwallApp` + `Contents/MacOS` + `Contents/Info.plist` + `Contents/Resources`).
- Ad-hoc codesign the bundle so Gatekeeper accepts it when launched locally (no Developer ID, no notarization).
- `Makefile` targets: `make build`, `make install`, `make uninstall`, `make run`. `make uninstall` preserves Application Support + Keychain items.
- Menu bar icon wired to an SF Symbol via `NSImage(systemSymbolName:)` (baseline `gauge.with.dots.needle.67percent`).
- Launch-at-login wired through `SMAppService.mainApp`; toggle exposed in `SettingsView`.
- Version metadata: `CFBundleShortVersionString` from a single-source `VERSION` file; `CFBundleVersion` from `git rev-list --count HEAD`.
- First-launch health check (run once per install) that probes Application Support write access + Keychain round-trip and logs two events through the existing `DiagnosticEventStore`.
- "Welcome to Pitwall" one-time first-launch banner explaining no ClaudeUsage migration and directing the user to paste credentials into the existing onboarding flow.

**Acceptance Criteria:**
- [ ] `make install` on a clean macOS 13+ system produces `/Applications/Pitwall.app`; `codesign --verify --verbose` exits 0.
- [ ] Double-clicking `Pitwall.app` launches without a Gatekeeper block (bundle was never quarantined because it was built locally).
- [ ] Menu bar shows the SF Symbol icon; clicking opens the Phase 3 popover without change.
- [ ] "Launch at Login" toggle in `SettingsView` flips `SMAppService.mainApp` state; verified by reboot.
- [ ] `make uninstall` removes the bundle and unregisters the login-item; Application Support + Keychain items remain intact; reinstall restores prior state.
- [ ] First-launch health check writes two `DiagnosticEventStore` events on first install and does not repeat on subsequent launches.
- [ ] `CFBundleShortVersionString` / `CFBundleVersion` are derived at build time, not hard-coded.
- [ ] macOS `swift build` + `swift test` still pass at the Phase 5 baseline (193/193) with zero regressions after Phase 6a lands.
- [ ] No new `import AppKit` / `import UserNotifications` / `import Security` in `PitwallShared` or platform shells.
- [ ] All phase tests pass (Phase 6a adds `PackagingVersionTests`, `LoginItemServiceTests`, `PackagingProbeTests`).
- [ ] No regressions in previous phase tests.

### Execution Profile
**Parallel mode:** serial
**Integration owner:** main agent
**Conflict risk:** medium
**Review gates:** correctness, tests, security, UX

**Subagent lanes:** none

### Implementation

- [x] Step 6a.1: Add the version source and an AppKit-free version derivation helper (completed 2026-04-22)
  - Files: create `VERSION` (content `1.0.0`), create `Sources/PitwallAppSupport/PackagingVersion.swift` (pure struct: `PackagingVersion` with `shortString`, `build`, and a `PackagingVersionProvider` protocol that exposes `current() -> PackagingVersion`; include a `StaticPackagingVersionProvider` fixture for tests), modify `Sources/PitwallApp/PitwallApp.swift` (or `AppDelegate.swift`) to read the version from a build-time constant or bundle lookup so the in-app About section can display it.
  - Rationale: version is touched by both the bundle builder (writes into `Info.plist`) and the in-app About view. Centralize the in-process side in `PitwallAppSupport` behind a protocol seam so it is unit-testable without launching the app.
  - The `VERSION` file is the single source of truth for `CFBundleShortVersionString`. `CFBundleVersion` is computed at build time via `git rev-list --count HEAD`.

- Step 6a.2: Build the `.app` bundle wrapper script
  - Files: create `scripts/build-app-bundle.sh` (shell script that runs `swift build --configuration release --product PitwallApp`, constructs `build/Pitwall.app/Contents/{MacOS,Resources}`, copies the built binary to `Contents/MacOS/PitwallApp`, copies an expanded `Info.plist` with real `CFBundleShortVersionString` + `CFBundleVersion` + `CFBundleExecutable=PitwallApp` + `NSHumanReadableCopyright`, and ad-hoc signs via `codesign --sign - --deep --force --options=runtime build/Pitwall.app`), modify `Sources/PitwallApp/Info.plist` (add `CFBundleExecutable`, `NSHumanReadableCopyright`; keep `LSUIElement=true`, `LSMinimumSystemVersion=13.0`; leave version strings as `{{CFBundleShortVersionString}}` / `{{CFBundleVersion}}` placeholders the script substitutes).
  - Script must use `set -euo pipefail`, exit non-zero on any failure, and be idempotent (`rm -rf build/Pitwall.app` before re-assembling).

- Step 6a.3: Add the `Makefile` with build / install / uninstall / run / clean targets
  - Files: create `Makefile` at repo root.
  - `make build` → runs `scripts/build-app-bundle.sh`.
  - `make install` → depends on `build`; replaces `/Applications/Pitwall.app` atomically (`rm -rf` then `cp -R`); verifies with `codesign --verify --verbose`; prints "Open Pitwall from /Applications — it will appear in your menu bar."
  - `make uninstall` → invokes the app binary with a `--unregister-login-item` flag (added in Step 6a.5) to unregister `SMAppService.mainApp`; removes `/Applications/Pitwall.app`; prints that Application Support + Keychain data are preserved.
  - `make run` → `open build/Pitwall.app` after build.
  - `make clean` → removes `build/`.

- Step 6a.4: Wire the menu bar SF Symbol icon
  - Files: modify `Sources/PitwallApp/MenuBarController.swift`.
  - Replace the current status-item image with `NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Pitwall")`.
  - No `.imageset` / `.icns` asset; SF Symbol only (reserved upgrade slot for Phase 6b).

- Step 6a.5: Wire the `SMAppService` login-item and Settings toggle
  - Files: create `Sources/PitwallAppSupport/LoginItemService.swift` (`LoginItemService` protocol with `isEnabled: Bool { get }` and `setEnabled(_:) throws`; `SMAppServiceLoginItemService` implementation wrapping `SMAppService.mainApp`; `InMemoryLoginItemService` fixture for tests), modify `Sources/PitwallApp/Views/SettingsView.swift` to bind the existing Launch-at-Login `Toggle` through the service and surface a friendly error state if `setEnabled` throws, modify `Sources/PitwallApp/AppDelegate.swift` or `PitwallApp.swift` to inject the service and to handle a `--unregister-login-item` CLI flag that immediately calls `SMAppService.mainApp.unregister()` and exits 0.
  - `Package.swift`: add `.linkedFramework("ServiceManagement")` to `PitwallApp`'s `linkerSettings`.

- Step 6a.6: Add the first-launch Application Support + Keychain health probe
  - Files: create `Sources/PitwallAppSupport/PackagingProbe.swift` (`PackagingProbeResult` struct; `PackagingProbe` takes a `FileManager`, an app-support root URL, and a `ProviderSecretStore` reference for the round-trip test; `runOnce(eventStore:, defaults:, firstLaunchKey:)` returns early if the `UserDefaults` key is set, otherwise runs both probes, appends two `DiagnosticEventStore` events, and sets the key), modify `Sources/PitwallApp/MenuBarController.swift` or `AppDelegate.swift` to call `runOnce(...)` exactly once at startup.
  - Keychain round-trip uses a disposable service name (e.g., `com.pitwall.app.packaging-probe`, account `probe`, random value) and must NOT touch any production `ProviderSecretKey`.
  - No network, no upload. Redaction path remains subject to `DiagnosticsRedactor`.

- Step 6a.7: Add the "Welcome to Pitwall" first-launch banner
  - Files: create `Sources/PitwallApp/Views/WelcomeBannerView.swift`, modify `Sources/PitwallApp/Views/PopoverContentView.swift` to conditionally render the banner gated on a `UserDefaults` key (`pitwall.welcome.v1.dismissed`).
  - Banner copy must include: "Welcome to Pitwall. You're replacing a previous menu bar app — Pitwall does not copy data from it." + "Paste your Claude `sessionKey` and `lastActiveOrg` in Settings → Claude account to get started." + "Secrets are stored in the macOS Keychain."
  - Dismiss button sets the key and hides the banner forever.

- Step 6a.8: Add the install smoke-test script
  - Files: create `scripts/smoke-install.sh` that builds into a tmp prefix, asserts `Contents/MacOS/PitwallApp` exists and is executable, asserts `Contents/Info.plist` has both version strings filled in (via `defaults read`), runs `codesign --verify --verbose` against the tmp bundle, and tears down.
  - Must use `set -euo pipefail` and exit non-zero on any failure.

### Green

- Step 6a.9: Write regression tests covering the new code paths
  - Files: create `Tests/PitwallAppSupportTests/PackagingVersionTests.swift` (asserts `shortString` matches `VERSION`-file content via the provider protocol; `build` is a positive integer), create `Tests/PitwallAppSupportTests/LoginItemServiceTests.swift` (uses `InMemoryLoginItemService` to assert toggle behavior + idempotency), create `Tests/PitwallAppSupportTests/PackagingProbeTests.swift` (in-memory `FileManager` seam + `InMemorySecretStore` + fresh `UserDefaults`; first `runOnce` writes two events and sets the key; second `runOnce` is a no-op; Application Support write failure is logged as `appSupportWritable: false` with an error string; Keychain mismatch is logged as `keychainRoundTripSucceeded: false`).
  - Reuse Phase 2's `InMemorySecretStore` — do not duplicate.
  - No XCUITest / snapshot tests for the banner; exercise the `UserDefaults` gate indirectly through a small view-model unit test if feasible.

- Step 6a.10: Run the full test suite and packaging smoke checks
  - Commands: `swift build`, `swift test` (confirm Phase 5's 193-test baseline plus the new Phase 6a tests all pass, zero regressions), `scripts/smoke-install.sh` (exits 0), `make build` then `open build/Pitwall.app` visual confirmation, `make install` then visual confirmation that `/Applications/Pitwall.app` shows the SF Symbol icon in the menu bar, `make uninstall` then `ls /Applications/Pitwall.app` fails + `ls ~/Library/Application\ Support/Pitwall/` succeeds + `security find-generic-password` still finds provider secrets.
  - Record the new test count in `tasks/history.md` as the Phase 6a baseline.

- Step 6a.11: Refactor while keeping tests green if needed
  - Files: touch only the new Phase 6a files + `Sources/PitwallApp/Views/SettingsView.swift` / `MenuBarController.swift` / `AppDelegate.swift` / `PitwallApp.swift`.
  - No refactor of Phase 1-5 code. If a Phase 6a step exposes a gap in a Phase 1-5 contract, record as a post-6a follow-up rather than widening 6a.

### Milestone: Phase 6a macOS Local Install
**Acceptance Criteria:**
- [ ] `make install` on a clean macOS 13+ system produces `/Applications/Pitwall.app`; `codesign --verify --verbose` exits 0.
- [ ] Double-clicking `Pitwall.app` launches without a Gatekeeper block.
- [ ] Menu bar shows the SF Symbol icon; clicking opens the Phase 3 popover unchanged.
- [ ] "Launch at Login" toggle flips `SMAppService.mainApp` state; verified by reboot.
- [ ] `make uninstall` removes the bundle and unregisters the login-item; Application Support + Keychain items remain intact; reinstall restores prior state.
- [ ] First-launch health check writes two `DiagnosticEventStore` events on first install and does not repeat on subsequent launches.
- [ ] `CFBundleShortVersionString` / `CFBundleVersion` are derived at build time, not hard-coded.
- [ ] macOS `swift build` + `swift test` pass at the Phase 5 baseline + new Phase 6a tests with zero regressions.
- [ ] No new `import AppKit` / `import UserNotifications` / `import Security` in `PitwallShared` or platform shells.
- [ ] All phase tests pass.
- [ ] No regressions in previous phase tests.

**On Completion** (fill in when phase is done):
- Deviations from plan: [none, or describe]
- Tech debt / follow-ups: [none, or list]
- Ready for next phase: yes/no

## Phase 6b: macOS Public Release (deferred)

Not scoped for immediate execution. See `tasks/roadmap.md` → Phase 6b for goals, scope, acceptance criteria, and manual-task prerequisites. Plan just-in-time via `/plan-phase 6b` only after Phase 6a ships and the user confirms intent to distribute publicly.

## Post-v1 / Post-packaging Follow-ups (not scheduled)

Documented platform limitations carried forward from the Phase 5 CI gap. They do not have an owning phase yet; promote into a new phase when ready.

- Wire a real Windows CI runner and `swift build --triple x86_64-unknown-windows-msvc` + `swift test` on a Windows host.
- Wire a real Linux CI runner and `swift build` + `swift test` on a Linux host.
- Wire production Windows Credential Manager behind `WindowsCredentialManagerBackend`.
- Wire production `libsecret` / Secret Service behind `LinuxSecretServiceBackend`.
- Wire production WinRT `ToastNotificationManager` behind `WindowsToastDelivering`.
- Wire production `libnotify` / `org.freedesktop.Notifications` D-Bus behind `LinuxNotificationDelivering`.
- Wire production Win32 `Shell_NotifyIcon` tray glue on top of `WindowsTrayMenuViewModel`.
- Wire production `libayatana-appindicator` glue (plus "no tray available" fallback) on top of `LinuxTrayMenuViewModel`.
- Wire real filesystem probes for Codex/Gemini presence on Windows (`FindFirstFileW`) and Linux (`stat(2)`) behind existing `*FilesystemProbing` seams.
- End-to-end tray + notification UX validation on real Windows / Linux desktop sessions.
- Windows + Linux packaging specs analogous to `specs/pitwall-macos-packaging.md`, once real platform backends are wired.
