# Todo - Pitwall

> Current phase: 6b of 6b — macOS Public Release.
> Source roadmap: `tasks/roadmap.md`
> Project: Pitwall — clean-room macOS menu bar app for Claude/Codex/Gemini usage pacing.

## Priority Task Queue

- [x] `/run` — execute Phase 6b Step 6b.1 (Sparkle 2.x dependency, entitlements, Info.plist keys, build script updates).
- [x] `/run` — execute Phase 6b Step 6b.2 (wire Sparkle updater into AppDelegate and Settings UI).
- [x] `/run` — execute Phase 6b Step 6b.3 (create release automation script).
- [x] `/run` — execute Phase 6b Step 6b.4 (Makefile release target and appcast.xml template).
- [ ] `/run` — execute Phase 6b Step 6b.5 (Homebrew cask formula).
- [ ] `/guide` — complete Phase 6b manual prerequisites (Apple Developer enrollment, Developer ID cert, notarytool creds, Sparkle EdDSA key, appcast hosting, Homebrew tap). See `tasks/manual-todo.md`.
- [ ] `/run` — execute Phase 6b Step 6b.6 (fill in real Sparkle keys and appcast URL from completed prerequisites).
- [ ] `/run` — execute Phase 6b Step 6b.7 (regression tests for Sparkle integration and release pipeline).
- [ ] `/run` — execute Phase 6b Step 6b.8 (end-to-end release validation). Blocked on all manual prerequisites.
- [ ] `/run` — execute Phase 6b Step 6b.9 (refactor if needed while keeping tests green).

## Completed Phases

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity completed and archived to `tasks/phases/phase-5.md`.
- [x] Phase 6a macOS Local Install completed and archived to `tasks/phases/phase-6a.md`.

## Phase 6b: macOS Public Release

> Test strategy: tests-after

**Goal:** Turn the Phase 6a `.app` into a signed, notarized, auto-updating DMG that ships on GitHub Releases and optionally a Homebrew cask, so Pitwall can be downloaded and launched on machines other than the author's without Gatekeeper friction. Deferred until the author wants to share Pitwall widely.

**Scope:**
- Apple Developer Program enrollment (user-driven prerequisite, not an engineering deliverable).
- Developer ID Application certificate installed in the author's login Keychain; `.p12` backup in password manager.
- `notarytool` credentials stored via `xcrun notarytool store-credentials --apple-id … --team-id … pitwall-notary`.
- Sparkle 2.x integration: SwiftPM dependency added to `Package.swift`; `SUFeedURL` + `SUPublicEDKey` in `Info.plist`; `SPUStandardUpdaterController` wired into `AppDelegate`; EdDSA private key stored in password manager only (never committed).
- `make release VERSION=x.y.z` target that chains: SwiftPM release build → `.app` wrap → Developer ID codesign with hardened runtime + timestamp → DMG package → `xcrun notarytool submit --wait` → `xcrun stapler staple` → Sparkle EdDSA signature → appcast `<item>` append → `gh release create` + `appcast.xml` publish.
- Entitlements file (`Sources/PitwallApp/Pitwall.entitlements`) scoped for hardened runtime with no sandbox entitlement.
- Homebrew cask published in a self-hosted tap (`georgele/homebrew-pitwall`) or submitted to `homebrew-cask`. Final channel deferred to manual-todo resolution.
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
- [ ] All phase tests pass.
- [ ] No regressions in previous phase tests.

### Execution Profile
**Parallel mode:** serial
**Integration owner:** main agent
**Conflict risk:** medium
**Review gates:** correctness, tests, security, UX

**Subagent lanes:** none

### Implementation

- [x] Step 6b.1: Add Sparkle 2.x SwiftPM dependency, entitlements file, and Info.plist keys
  - Files: modify `Package.swift` (add `.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")` dependency; add `"Sparkle"` to `PitwallApp` target dependencies), create `Sources/PitwallApp/Pitwall.entitlements` (hardened runtime, no sandbox — keys: `com.apple.security.app-sandbox = false`, no other entitlements beyond what Phases 1-5 require), modify `Sources/PitwallApp/Info.plist` (add `SUFeedURL` with placeholder `{{SUFeedURL}}`, add `SUPublicEDKey` with placeholder `{{SUPublicEDKey}}`).
  - Modify `scripts/build-app-bundle.sh` to: (a) accept optional env vars `SIGNING_IDENTITY` (default `-` for ad-hoc), `ENTITLEMENTS_PATH` (default empty), `SU_FEED_URL` and `SU_PUBLIC_ED_KEY` (default empty — strip from plist when empty for local dev); (b) substitute or strip the Sparkle placeholders in the expanded Info.plist; (c) when `ENTITLEMENTS_PATH` is set, pass `--entitlements "$ENTITLEMENTS_PATH"` to `codesign`; (d) when `SIGNING_IDENTITY` is not `-`, add `--timestamp` to the codesign invocation.
  - Verify `swift build` still compiles and `make install` still works for ad-hoc local dev (no Sparkle keys = no auto-update UI, graceful).
  - Blocked on: manual-todo "Generate Sparkle 2.x EdDSA key pair" for real `SUPublicEDKey` value; manual-todo "Stand up appcast.xml hosting" for real `SUFeedURL` value. Step can proceed with placeholders for code integration; real values filled in Step 6b.6.

- [x] Step 6b.2: Wire Sparkle updater controller into AppDelegate and Settings UI
  - Files: modify `Sources/PitwallApp/AppDelegate.swift` (import `Sparkle`; init `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)` only when `SUFeedURL` is present in the bundle's Info.plist — skip silently for ad-hoc builds without Sparkle keys), modify `Sources/PitwallApp/Views/SettingsView.swift` (add an "Updates" section between "Startup" and "Notifications" with: "Check for Updates…" button that calls `updater.checkForUpdates()`, "Automatically check for updates" toggle bound to `updater.automaticallyChecksForUpdates`, update cadence picker bound to `updater.updateCheckInterval` with options: hourly / every 6 hours / daily / weekly), modify `Sources/PitwallApp/MenuBarController.swift` if the updater reference needs to flow through the controller to SettingsView.
  - The "Updates" section is hidden when Sparkle is not configured (ad-hoc builds), so Phase 6a `make install` UX is unchanged.
  - No new `import Sparkle` in `PitwallAppSupport`, `PitwallShared`, `PitwallCore`, or platform shells.

- [x] Step 6b.3: Create the release automation script
  - Files: create `scripts/release.sh` (`set -euo pipefail`; accepts `VERSION` as first positional arg or env var).
  - Script pipeline (each step exits non-zero on failure):
    1. Validate `VERSION` matches semver regex; validate working tree is clean (`git diff --quiet HEAD`).
    2. Call `bash scripts/build-app-bundle.sh` with `SIGNING_IDENTITY="Developer ID Application"`, `ENTITLEMENTS_PATH="Sources/PitwallApp/Pitwall.entitlements"`, `SU_FEED_URL` and `SU_PUBLIC_ED_KEY` from env or a local `.release-config` file (gitignored).
    3. `codesign --verify --verbose --deep build/Pitwall.app` + `spctl --assess --type execute build/Pitwall.app`.
    4. Create DMG: `hdiutil create -volname "Pitwall $VERSION" -srcfolder build/Pitwall.app -ov -format UDZO "build/Pitwall-${VERSION}.dmg"`.
    5. `xcrun notarytool submit "build/Pitwall-${VERSION}.dmg" --keychain-profile pitwall-notary --wait`.
    6. `xcrun stapler staple "build/Pitwall-${VERSION}.dmg"`.
    7. Generate Sparkle EdDSA signature: `./bin/sign_update "build/Pitwall-${VERSION}.dmg"` (Sparkle's bundled tool) and capture the `sparkle:edSignature` + `length` values.
    8. Append a new `<item>` to `appcast.xml` with version, signature, DMG URL, and release notes.
    9. `gh release create "v${VERSION}" "build/Pitwall-${VERSION}.dmg" --title "Pitwall ${VERSION}" --notes-file "build/release-notes.md"` (release notes extracted from git log since last tag).
    10. Copy updated `appcast.xml` to the hosting location (GitHub Pages push or raw file upload — exact mechanism depends on the hosting choice from manual-todo).
  - Create `.release-config.example` with placeholder keys for `SU_FEED_URL`, `SU_PUBLIC_ED_KEY`, `SIGNING_IDENTITY`, and document that `.release-config` is gitignored.
  - Add `.release-config` to `.gitignore`.
  - Add `--dry-run` flag that runs through validation + build + codesign but skips notarization, GitHub release, and appcast publish.

- [x] Step 6b.4: Add Makefile release target and initial appcast.xml template
  - Files: modify `Makefile` (add `.PHONY: release`; `release` target requires `VERSION` env var, validates it's set, calls `bash scripts/release.sh "$(VERSION)"`), create `appcast.xml` (empty Sparkle appcast template with `<rss>` + `<channel>` skeleton and no items — items are appended by `scripts/release.sh`).
  - Verify `make build`, `make install`, `make run`, `make clean` still work (no regression to Phase 6a targets).

- [ ] Step 6b.5: Create Homebrew cask formula
  - Files: create `Formula/pitwall.rb` (Homebrew cask formula pointing to the GitHub Releases DMG URL pattern `https://github.com/GeorgeQLe/pitwall/releases/download/v#{version}/Pitwall-#{version}.dmg`; SHA256 placeholder filled per release; `app "Pitwall.app"`).
  - Document in README.md the `brew install --cask pitwall` path (either via self-hosted tap `brew tap georgele/pitwall && brew install --cask pitwall`, or upstream submission — decision deferred to manual-todo resolution).

### Green

- [ ] Step 6b.6: Fill in real Sparkle keys and appcast URL from manual prerequisites
  - Requires: all Phase 6b manual-todo items completed (Apple Developer enrollment, Developer ID cert, notarytool creds, Sparkle EdDSA key pair, appcast hosting URL, Homebrew tap).
  - Files: modify `.release-config.example` with real feed URL pattern, update `Formula/pitwall.rb` with the real tap path if using self-hosted tap.
  - Verify `swift build` + `swift test` still pass.

- [ ] Step 6b.7: Write regression tests for Sparkle integration and release pipeline
  - Files: create `Tests/PitwallAppSupportTests/UpdaterSettingsTests.swift` (test that updater settings section is hidden when no `SUFeedURL` is present; test that cadence options map to expected `TimeInterval` values), modify existing tests as needed to confirm no regressions.
  - Shell validation: `bash scripts/release.sh --dry-run` runs through validation + build + codesign without notarization or publish.
  - Verify `make install` still works for ad-hoc local dev with no Sparkle keys configured.

- [ ] Step 6b.8: End-to-end release validation (blocked on all manual prerequisites)
  - Run `make release VERSION=1.0.0` on a clean tree with all credentials configured.
  - Verify: `spctl --assess --type open --context context:primary-signature build/Pitwall-1.0.0.dmg` succeeds; `xcrun stapler validate build/Pitwall-1.0.0.dmg` succeeds; download DMG from GitHub Releases on a different Mac and confirm no Gatekeeper dialog; Sparkle auto-update check works on launch and on-demand; `brew install --cask pitwall` installs and launches without issues.
  - Verify Phase 6a paths: `make install` / `make uninstall` still work; first-launch health check does not double-fire after Sparkle in-place update.
  - Run `swift build` + `swift test` — all Phase 1-6a tests pass with zero regressions.

- [ ] Step 6b.9: Refactor if needed while keeping tests green
  - Files: touch only Phase 6b files + `scripts/build-app-bundle.sh`, `scripts/release.sh`, `Makefile`, `Sources/PitwallApp/AppDelegate.swift`, `Sources/PitwallApp/Views/SettingsView.swift`.
  - No refactor of Phase 1-6a code. If Phase 6b exposes a gap in an earlier contract, record as a post-6b follow-up.

### Milestone: Phase 6b macOS Public Release
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
- [ ] All phase tests pass.
- [ ] No regressions in previous phase tests.

**On Completion** (fill in when phase is done):
- Deviations from plan: [none, or describe]
- Tech debt / follow-ups: [none, or list]
- Ready for next phase: yes/no

## Post-v1 / Post-packaging Follow-ups (not scheduled)

Documented platform limitations carried forward from the Phase 5 CI gap. They do not have an owning phase yet; promote into a new phase when ready. Each code-gated item below is blocked on a human-gated prerequisite tracked in `tasks/manual-todo.md` → "Cross-platform parity prerequisites" (Windows CI host, Linux CI host, end-to-end hardware UX validation).

- Wire production Windows Credential Manager behind `WindowsCredentialManagerBackend`. _Blocked on: Windows CI host._
- Wire production `libsecret` / Secret Service behind `LinuxSecretServiceBackend`. _Blocked on: Linux CI host._
- Wire production WinRT `ToastNotificationManager` behind `WindowsToastDelivering`. _Blocked on: Windows CI host._
- Wire production `libnotify` / `org.freedesktop.Notifications` D-Bus behind `LinuxNotificationDelivering`. _Blocked on: Linux CI host._
- Wire production Win32 `Shell_NotifyIcon` tray glue on top of `WindowsTrayMenuViewModel`. _Blocked on: Windows CI host._
- Wire production `libayatana-appindicator` glue (plus "no tray available" fallback) on top of `LinuxTrayMenuViewModel`. _Blocked on: Linux CI host._
- Wire real filesystem probes for Codex/Gemini presence on Windows (`FindFirstFileW`) and Linux (`stat(2)`) behind existing `*FilesystemProbing` seams. _Blocked on: Windows + Linux CI hosts._
- Windows + Linux packaging specs analogous to `specs/pitwall-macos-packaging.md`, once real platform backends are wired.
