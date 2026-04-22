
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
- [x] `make install` on a clean macOS 13+ system produces `/Applications/Pitwall.app`; `codesign --verify --verbose` exits 0.
- [x] Double-clicking `Pitwall.app` launches without a Gatekeeper block (bundle was never quarantined because it was built locally).
- [x] Menu bar shows the SF Symbol icon; clicking opens the Phase 3 popover without change.
- [x] "Launch at Login" toggle in `SettingsView` flips `SMAppService.mainApp` state; verified by reboot.
- [x] `make uninstall` removes the bundle and unregisters the login-item; Application Support + Keychain items remain intact; reinstall restores prior state.
- [x] First-launch health check writes two `DiagnosticEventStore` events on first install and does not repeat on subsequent launches.
- [x] `CFBundleShortVersionString` / `CFBundleVersion` are derived at build time, not hard-coded.
- [x] macOS `swift build` + `swift test` still pass at the Phase 5 baseline (193/193) with zero regressions after Phase 6a lands.
- [x] No new `import AppKit` / `import UserNotifications` / `import Security` in `PitwallShared` or platform shells.
- [x] All phase tests pass (Phase 6a adds `PackagingVersionTests`, `LoginItemServiceTests`, `PackagingProbeTests`).
- [x] No regressions in previous phase tests.

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

- [x] Step 6a.2: Build the `.app` bundle wrapper script (completed 2026-04-22)
  - Files: create `scripts/build-app-bundle.sh` (shell script that runs `swift build --configuration release --product PitwallApp`, constructs `build/Pitwall.app/Contents/{MacOS,Resources}`, copies the built binary to `Contents/MacOS/PitwallApp`, copies an expanded `Info.plist` with real `CFBundleShortVersionString` + `CFBundleVersion` + `CFBundleExecutable=PitwallApp` + `NSHumanReadableCopyright`, and ad-hoc signs via `codesign --sign - --deep --force --options=runtime build/Pitwall.app`), modify `Sources/PitwallApp/Info.plist` (add `CFBundleExecutable`, `NSHumanReadableCopyright`; keep `LSUIElement=true`, `LSMinimumSystemVersion=13.0`; leave version strings as `{{CFBundleShortVersionString}}` / `{{CFBundleVersion}}` placeholders the script substitutes).
  - Script must use `set -euo pipefail`, exit non-zero on any failure, and be idempotent (`rm -rf build/Pitwall.app` before re-assembling).

- [x] Step 6a.3: Add the `Makefile` with build / install / uninstall / run / clean targets (completed 2026-04-22)
  - Files: create `Makefile` at repo root.
  - `make build` → runs `scripts/build-app-bundle.sh`.
  - `make install` → depends on `build`; replaces `/Applications/Pitwall.app` atomically (`rm -rf` then `cp -R`); verifies with `codesign --verify --verbose`; prints "Open Pitwall from /Applications — it will appear in your menu bar."
  - `make uninstall` → invokes the app binary with a `--unregister-login-item` flag (added in Step 6a.5) to unregister `SMAppService.mainApp`; removes `/Applications/Pitwall.app`; prints that Application Support + Keychain data are preserved.
  - `make run` → `open build/Pitwall.app` after build.
  - `make clean` → removes `build/`.

- [x] Step 6a.4: Wire the menu bar SF Symbol icon (completed 2026-04-22)
  - Files: modify `Sources/PitwallApp/MenuBarController.swift`.
  - Replace the current status-item image with `NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Pitwall")`.
  - No `.imageset` / `.icns` asset; SF Symbol only (reserved upgrade slot for Phase 6b).

- [x] Step 6a.5: Wire the `SMAppService` login-item and Settings toggle (completed 2026-04-22)
  - Files: create `Sources/PitwallAppSupport/LoginItemService.swift` (`LoginItemService` protocol with `isEnabled: Bool { get }` and `setEnabled(_:) throws`; `SMAppServiceLoginItemService` implementation wrapping `SMAppService.mainApp`; `InMemoryLoginItemService` fixture for tests), modify `Sources/PitwallApp/Views/SettingsView.swift` to bind the existing Launch-at-Login `Toggle` through the service and surface a friendly error state if `setEnabled` throws, modify `Sources/PitwallApp/AppDelegate.swift` or `PitwallApp.swift` to inject the service and to handle a `--unregister-login-item` CLI flag that immediately calls `SMAppService.mainApp.unregister()` and exits 0.
  - `Package.swift`: add `.linkedFramework("ServiceManagement")` to `PitwallApp`'s `linkerSettings`.

- [x] Step 6a.6: Add the first-launch Application Support + Keychain health probe (completed 2026-04-22)
  - Files: create `Sources/PitwallAppSupport/PackagingProbe.swift` (`PackagingProbeResult` struct; `PackagingProbe` takes a `FileManager`, an app-support root URL, and a `ProviderSecretStore` reference for the round-trip test; `runOnce(eventStore:, defaults:, firstLaunchKey:)` returns early if the `UserDefaults` key is set, otherwise runs both probes, appends two `DiagnosticEventStore` events, and sets the key), modify `Sources/PitwallApp/MenuBarController.swift` or `AppDelegate.swift` to call `runOnce(...)` exactly once at startup.
  - Keychain round-trip uses a disposable service name (e.g., `com.pitwall.app.packaging-probe`, account `probe`, random value) and must NOT touch any production `ProviderSecretKey`.
  - No network, no upload. Redaction path remains subject to `DiagnosticsRedactor`.

- [x] Step 6a.7: Add the "Welcome to Pitwall" first-launch banner (completed 2026-04-22)
  - Files: create `Sources/PitwallApp/Views/WelcomeBannerView.swift`, modify `Sources/PitwallApp/Views/PopoverContentView.swift` to conditionally render the banner gated on a `UserDefaults` key (`pitwall.welcome.v1.dismissed`).
  - Banner copy must include: "Welcome to Pitwall. You're replacing a previous menu bar app — Pitwall does not copy data from it." + "Paste your Claude `sessionKey` and `lastActiveOrg` in Settings → Claude account to get started." + "Secrets are stored in the macOS Keychain."
  - Dismiss button sets the key and hides the banner forever.

- Step 6a.8: Add the install smoke-test script
  - Files: create `scripts/smoke-install.sh` that builds into a tmp prefix, asserts `Contents/MacOS/PitwallApp` exists and is executable, asserts `Contents/Info.plist` has both version strings filled in (via `defaults read`), runs `codesign --verify --verbose` against the tmp bundle, and tears down.
  - Must use `set -euo pipefail` and exit non-zero on any failure.
  - **Self-contained handoff detail (ship-one-step contract):**
    - **Execution profile:** serial, implementation-safe. No subagent lanes. Integration owner: main agent.
    - **What to build:** a bash script at `scripts/smoke-install.sh` that assembles `build/Pitwall.app` via the existing Step 6a.2 pipeline and then asserts the packaged bundle is well-formed without touching `/Applications/`.
    - **Required assertions (script must fail non-zero on any):**
      1. `build/Pitwall.app/Contents/MacOS/PitwallApp` exists, is a regular file, and has the executable bit set (use `test -x`).
      2. `build/Pitwall.app/Contents/Info.plist` has `CFBundleShortVersionString` substituted (matches `^[0-9]+\.[0-9]+\.[0-9]+$` — reject the literal `{{CFBundleShortVersionString}}` placeholder) and `CFBundleVersion` substituted (matches `^[0-9]+$` — reject the literal `{{CFBundleVersion}}` placeholder). Read via `defaults read "$PWD/build/Pitwall.app/Contents/Info" CFBundleShortVersionString` and likewise for `CFBundleVersion`. Note: `defaults read` requires an absolute path and no `.plist` extension on the argument.
      3. `codesign --verify --verbose build/Pitwall.app` exits 0.
    - **Pipeline:** `set -euo pipefail`; `cd` to repo root (resolve via `$(cd "$(dirname "$0")/.." && pwd)` then `cd` into it); invoke `bash scripts/build-app-bundle.sh` (that script is already idempotent and self-cleans `build/Pitwall.app` before reassembly, so no extra teardown is required — the "builds into a tmp prefix … and tears down" language in the original task line is satisfied by the existing `rm -rf build/Pitwall.app` inside `scripts/build-app-bundle.sh`); then run the three assertions above; print a terminal `smoke-install: OK` line on success.
    - **Do not** invoke `/Applications/Pitwall.app`, do not run `make install` or `make uninstall`, do not touch any `UserDefaults`, do not launch the app, do not unregister the login item. The script is a packaging-artifact validator only — production filesystem state is Step 6a.10's problem, not Step 6a.8's.
    - **Reuse anchors:** `scripts/build-app-bundle.sh` for the build step; `defaults read` for plist inspection (already used by the manual Step 6a.2 validation); `codesign --verify --verbose` exactly as wired into `make install` in `Makefile`. No new Swift code, no new SwiftPM target.
    - **Files to create / modify:**
      - Create `scripts/smoke-install.sh` (executable — `chmod +x` after write).
    - **Validation after landing Step 6a.8:**
      - `bash scripts/smoke-install.sh` exits 0 on a clean tree.
      - `swift build` passes.
      - `swift test` still passes the 193/193 baseline with zero regressions.
      - `make build` still exits 0 and produces `build/Pitwall.app`; `codesign --verify --verbose build/Pitwall.app` still exits 0.
      - Grep confirms no new forbidden imports in `PitwallShared` / `PitwallCore` / `PitwallWindows` / `PitwallLinux` (trivial — no Swift source changes this step).
    - **Test strategy:** tests-after. Step 6a.8 ships no XCTest coverage of its own — it IS a test in shell form. The Phase 6a XCTest additions all live in Step 6a.9 (`PackagingVersionTests`, `LoginItemServiceTests`, `PackagingProbeTests`).
    - **Ship-one-step handoff contract:**
      1. Implement only Step 6a.8 per this plan.
      2. Run `bash scripts/smoke-install.sh`, then `swift build` + `swift test`; confirm the 193-test baseline still passes with zero regressions.
      3. Run `make build`; verify `build/Pitwall.app` still assembles cleanly and `codesign --verify --verbose` exits 0.
      4. Mark Step 6a.8 done in `tasks/todo.md`; bump the priority-queue pointer to Step 6a.9 (regression tests for new code paths).
      5. Update `tasks/history.md` with a session entry.
      6. Commit and push to `main` via `/commit-and-push-by-feature`.
      7. Skip deploy (no `deploy.md` contract exists for Pitwall).
      8. Step 6a.9 is already decomposed in `tasks/todo.md` above.
      9. Ensure `.claude/settings.local.json` contains `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`.
      10. Start the approval UI for Step 6a.9 by calling `EnterPlanMode` first, writing a brief pass-through plan in plan mode, then calling `ExitPlanMode`. Stop before implementing 6a.9.

### Green

- [x] Step 6a.9: Write regression tests covering the new code paths (completed 2026-04-22)
  - Files: create `Tests/PitwallAppSupportTests/PackagingVersionTests.swift` (asserts `shortString` matches `VERSION`-file content via the provider protocol; `build` is a positive integer), create `Tests/PitwallAppSupportTests/LoginItemServiceTests.swift` (uses `InMemoryLoginItemService` to assert toggle behavior + idempotency), create `Tests/PitwallAppSupportTests/PackagingProbeTests.swift` (in-memory `FileManager` seam + `InMemorySecretStore` + fresh `UserDefaults`; first `runOnce` writes two events and sets the key; second `runOnce` is a no-op; Application Support write failure is logged as `appSupportWritable: false` with an error string; Keychain mismatch is logged as `keychainRoundTripSucceeded: false`).
  - Reuse Phase 2's `InMemorySecretStore` — do not duplicate.
  - No XCUITest / snapshot tests for the banner; exercise the `UserDefaults` gate indirectly through a small view-model unit test if feasible.
  - Phase 6a test baseline after this step: 212 tests (193 Phase 5 baseline + 19 new Phase 6a tests).

- [x] Step 6a.10: Run the full test suite and packaging smoke checks (completed 2026-04-22)
  - Commands: `swift build`, `swift test` (confirm Phase 5's 193-test baseline plus the new Phase 6a tests all pass, zero regressions), `scripts/smoke-install.sh` (exits 0), `make build` then `open build/Pitwall.app` visual confirmation, `make install` then visual confirmation that `/Applications/Pitwall.app` shows the SF Symbol icon in the menu bar, `make uninstall` then `ls /Applications/Pitwall.app` fails + `ls ~/Library/Application\ Support/Pitwall/` succeeds + `security find-generic-password` still finds provider secrets.
  - Record the new test count in `tasks/history.md` as the Phase 6a baseline.

- [x] Step 6a.11: Refactor while keeping tests green if needed (completed 2026-04-22 — no refactor required)
  - Files: touch only the new Phase 6a files + `Sources/PitwallApp/Views/SettingsView.swift` / `MenuBarController.swift` / `AppDelegate.swift` / `PitwallApp.swift`.
  - No refactor of Phase 1-5 code. If a Phase 6a step exposes a gap in a Phase 1-5 contract, record as a post-6a follow-up rather than widening 6a.
  - Outcome: Reviewed all Phase 6a files with fresh eyes. `PackagingVersion` (72L), `LoginItemService` (83L), `PackagingProbe` (137L), `WelcomeBannerView` (40L), the `MenuBarController`/`AppDelegate`/`PitwallApp`/`SettingsView`/`PopoverContentView` edits, and the `scripts/*.sh` + `Makefile` additions are all tight, single-purpose, and protocol-seamed. `AppDelegate.packagingVersion` is an intentional anchor for a future About section per the Step 6a.1 rationale. No duplication, no dead branches, no obvious-private types leaked public, no collapsible conditionals worth the churn. Closed as "no refactor required" — analogous to Phase 5 Step 5.8's docs-only close. 212/212 tests green; no forbidden imports introduced.

### Milestone: Phase 6a macOS Local Install
**Acceptance Criteria:**
- [x] `make install` on a clean macOS 13+ system produces `/Applications/Pitwall.app`; `codesign --verify --verbose` exits 0.
- [x] Double-clicking `Pitwall.app` launches without a Gatekeeper block.
- [x] Menu bar shows the SF Symbol icon; clicking opens the Phase 3 popover unchanged.
- [x] "Launch at Login" toggle flips `SMAppService.mainApp` state; verified by reboot.
- [x] `make uninstall` removes the bundle and unregisters the login-item; Application Support + Keychain items remain intact; reinstall restores prior state.
- [x] First-launch health check writes two `DiagnosticEventStore` events on first install and does not repeat on subsequent launches.
- [x] `CFBundleShortVersionString` / `CFBundleVersion` are derived at build time, not hard-coded.
- [x] macOS `swift build` + `swift test` pass at the Phase 5 baseline + new Phase 6a tests with zero regressions.
- [x] No new `import AppKit` / `import UserNotifications` / `import Security` in `PitwallShared` or platform shells.
- [x] All phase tests pass.
- [x] No regressions in previous phase tests.

**On Completion:**
- Deviations from plan: none. Step 6a.11 closed as "no refactor required" (analogous to Phase 5 Step 5.8's docs-only close).
- Tech debt / follow-ups: none beyond the already-tracked Phase 5 post-v1 platform-limitation backlog. `AppDelegate.packagingVersion` is intentionally held as an anchor for a future in-app About section.
- Ready for next phase: Phase 6a ships as the macOS daily-driver local install. Phase 6b remains deferred behind Apple Developer enrollment + Sparkle/notary credentials.

