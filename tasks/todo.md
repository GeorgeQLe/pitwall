# Todo - Pitwall

> Current phase: 6a of 6b — macOS Local Install (packaging phase, appended post-v1).
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [ ] `/plan-phase 6a` — decompose Phase 6a "macOS Local Install" into implementation steps. Evidence: `tasks/roadmap.md` just appended Phases 6a + 6b (mtime > all phase archives); `specs/pitwall-macos-packaging.md` exists with full scope; no `### Tests First` / `### Implementation` / `### Green` sections exist for Phase 6a yet, so `/run` cannot execute it.
- [ ] After Phase 6a ships: `/plan-phase 6b` — Phase 6b is deferred until the author decides to share Pitwall publicly; blocked on Apple Developer enrollment ($99/yr) and Sparkle/notary credential setup. Do not plan 6b until 6a is complete and the user confirms intent to go public.

## Completed Phases

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity completed and archived to `tasks/phases/phase-5.md`.

## Phase 6a: macOS Local Install

> Test strategy: tests-after (pure packaging work; existing Phase 1-5 XCTest suite remains the regression gate).

**Goal:** Turn the existing `PitwallApp` SwiftPM executable into a `.app` bundle the author can drop into `/Applications` with a single `make install`, so Pitwall can replace the legacy ClaudeUsage menu bar as a daily driver without any Apple Developer Program cost.

**Scope summary** (full detail in `tasks/roadmap.md` → Phase 6a and `specs/pitwall-macos-packaging.md` → Phase 6a):

- `.app` bundle wrapper around the SwiftPM release executable.
- Ad-hoc codesign (`codesign --sign - --deep --force`).
- `Makefile` targets: `make build`, `make install`, `make uninstall`, `make run`.
- `make uninstall` preserves Application Support + Keychain items (data-preserving).
- Menu bar icon via SF Symbol (`NSImage(systemSymbolName:)`) — no binary asset.
- Launch-at-login via `SMAppService.mainApp` wired into the existing `SettingsView` toggle.
- Version metadata: `CFBundleShortVersionString` from `VERSION` file, `CFBundleVersion` from `git rev-list --count HEAD`.
- First-launch health probe (Application Support writable + Keychain round-trip) logged to `DiagnosticEventStore`; gated by `UserDefaults` key so it runs once per install.
- "Welcome to Pitwall" one-time first-launch banner explaining no ClaudeUsage migration.

**Files expected to change** (confirm during `/plan-phase 6a`):

- `Package.swift` (minor, if any; likely no change).
- `Sources/PitwallApp/Info.plist` (real version strings, `CFBundleExecutable`, `NSHumanReadableCopyright`).
- `Sources/PitwallApp/MenuBarController.swift` (SF Symbol wiring, first-launch probe hook).
- `Sources/PitwallApp/Views/SettingsView.swift` (Launch-at-login toggle → `SMAppService`; About section).
- `Sources/PitwallApp/AppDelegate.swift` (first-launch banner gating).
- New `Sources/PitwallApp/PackagingProbe.swift` (Application Support + Keychain probe, pure struct + protocol seam).
- New `scripts/build-app-bundle.sh` (SwiftPM executable → `.app` wrapper).
- New `Makefile` (`build` / `install` / `uninstall` / `run` targets).
- New `VERSION` file at repo root.
- `Tests/PitwallAppSupportTests/` — new tests for the packaging-probe protocol seam and version-string derivation helper.

**Execution profile** (confirm during `/plan-phase 6a`):

- **Parallel mode:** serial.
- **Integration owner:** main agent.
- **Conflict risk:** medium (touches `Sources/PitwallApp/` + new top-level tooling).
- **Review gates:** correctness, tests, docs, UX (menu bar icon + settings toggle), security (codesign + login-item API usage).
- **Subagent lanes:** none.

**Implementation steps:** not yet decomposed. Run `/plan-phase 6a` to generate them with the Tests-after structure and file-level detail required by `/run`.

## Phase 6b: macOS Public Release (deferred)

Not scoped for immediate execution. See `tasks/roadmap.md` → Phase 6b for goals, scope, acceptance criteria, and the manual-task prerequisites (Apple Developer enrollment, Developer ID cert, notarytool credential, Sparkle EdDSA key pair, appcast hosting URL, Homebrew tap/cask). Plan just-in-time via `/plan-phase 6b` only after Phase 6a ships and the user confirms intent to distribute publicly.

## Post-v1 / Post-packaging Follow-ups (not scheduled)

Documented platform limitations carried forward from the Phase 5 CI gap. They do not have an owning phase yet; promote into a new phase (or a focused hardening pass) when the team is ready to close them.

- Wire a real Windows CI runner and `swift build --triple x86_64-unknown-windows-msvc` + `swift test` on a Windows host.
- Wire a real Linux CI runner and `swift build` + `swift test` on a Linux host.
- Wire production Windows Credential Manager (`CredWriteW` / `CredReadW` / `CredDeleteW`) behind `WindowsCredentialManagerBackend`.
- Wire production `libsecret` / Secret Service behind `LinuxSecretServiceBackend`.
- Wire production WinRT `ToastNotificationManager` behind `WindowsToastDelivering`.
- Wire production `libnotify` / `org.freedesktop.Notifications` D-Bus behind `LinuxNotificationDelivering`.
- Wire production Win32 `Shell_NotifyIcon` tray glue on top of `WindowsTrayMenuViewModel`.
- Wire production `libayatana-appindicator` glue (plus the "no tray available" windowed popover fallback) on top of `LinuxTrayMenuViewModel`.
- Wire real filesystem probes for Codex/Gemini presence on Windows (`FindFirstFileW`-backed) and Linux (`stat(2)`-backed) behind the existing `*CodexFilesystemProbing` / `*GeminiFilesystemProbing` seams.
- End-to-end tray + notification UX validation in a real Windows or Linux desktop session.
- Windows and Linux packaging specs (analogous to `specs/pitwall-macos-packaging.md`) once real platform backends are wired.
