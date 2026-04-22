# Pitwall macOS Packaging And Distribution

## Summary

Pitwall's Phase 1-5 product work delivered a functional macOS menu bar app (`PitwallApp` SwiftPM executable) with real Claude usage networking, Codex/Gemini passive detection, Keychain-backed credential storage, Phase 4 history/diagnostics/notifications/GitHub heatmap coverage, and 193/193 test pass rate. It cannot yet replace the legacy ClaudeUsage menu bar for end users because there is no `.app` bundle build, no code signing, no login-item wiring, no app icon, no DMG, and no update channel.

This spec covers the packaging and distribution work needed to turn the existing executable into a shippable menu bar app. It is explicitly split into two phases so a personal daily-driver replacement can ship immediately without waiting on Apple Developer enrollment or notarization infrastructure.

The first release should answer:

- Can the author replace their daily-driver ClaudeUsage menu bar with Pitwall using a single `make install` command, with zero Apple Developer cost and no terminal theatrics after install?
- Once the author decides to share Pitwall, can a second `make release` command take the same codebase to a signed, notarized, Sparkle-updatable DMG on GitHub Releases (and optionally a Homebrew cask)?

## Non-Goals

- No Mac App Store distribution. Sandbox entitlements break Keychain access patterns, filesystem probing of `~/.codex` / `~/.gemini`, and the Claude cookie-bearing network requests required by `ClaudeUsageClient`. The app is and will remain direct-download-only.
- No automated migration of data from the legacy ClaudeUsage app. Users re-enter their `sessionKey` and `lastActiveOrg` in Pitwall's onboarding flow. Reading a ClaudeUsage-authored Keychain item or config file is out of scope to keep the clean-room boundary intact.
- No remote crash reporting or analytics upload. Phase 4 diagnostics remain local-only and user-exported.
- No GitHub Actions runner in Phase 6a or 6b. The release pipeline is a local `make release` script. CI for macOS packaging is a post-6b follow-up.
- No Windows or Linux packaging. Those are post-v1 follow-ups tracked under the Phase 5 platform-limitation list and will get their own specs when real backends are wired.
- No paid cross-signing service (e.g., third-party notary relays). Notarization in 6b uses Apple's `notarytool` directly.

## Platform

- macOS 13+ (matches `LSMinimumSystemVersion` in existing `Sources/PitwallApp/Info.plist`).
- Swift toolchain: Apple Swift 6.2+ (`arm64-apple-macosx`).
- SwiftPM remains the single source of truth for the build. The package manifest at `Package.swift` is not replaced with an Xcode project.
- `.app` bundle layout is produced by a build script that wraps the SwiftPM executable output rather than by `xcodebuild`.
- Signing in Phase 6a: ad-hoc (`codesign --sign -`).
- Signing in Phase 6b: Developer ID Application certificate from Apple Developer Program.
- Notarization in Phase 6b: `xcrun notarytool submit --wait` + `xcrun stapler staple`.
- Auto-update in Phase 6b: Sparkle 2.x with EdDSA-signed appcast.

## Phase 6a: Personal Local Install (ships first, $0)

### Goal

Replace the author's daily-driver ClaudeUsage menu bar with Pitwall using a single `make install` command. No Apple Developer account. No notarization. No Sparkle. No DMG.

### Deliverables

- `scripts/build-app-bundle.sh` — wraps `swift build --configuration release --product PitwallApp` output into `build/Pitwall.app` with the correct `Contents/MacOS`, `Contents/Resources`, `Contents/Info.plist` layout.
- `Makefile` targets: `make build`, `make install`, `make uninstall`, `make run`.
  - `make build` — builds the release binary and wraps it into `build/Pitwall.app`.
  - `make install` — depends on `make build`, ad-hoc signs (`codesign --sign - --deep --force`), and copies `build/Pitwall.app` into `/Applications/Pitwall.app`. Prints a final "Open Pitwall from /Applications — it will appear in your menu bar" message.
  - `make uninstall` — removes `/Applications/Pitwall.app` and unregisters the login-item via `SMAppService`. Preserves `~/Library/Application Support/Pitwall/` and Keychain items so reinstall keeps state.
  - `make run` — builds and runs the bundle in place for a fast iteration loop.
- `Sources/PitwallApp/Info.plist` updates: real `CFBundleShortVersionString` (starts at `1.0.0`), real `CFBundleVersion` (git commit count), `CFBundleExecutable = PitwallApp`, `NSHumanReadableCopyright`, keep `LSUIElement = true`, keep `LSMinimumSystemVersion = 13.0`.
- Menu bar icon wired via `NSImage(systemSymbolName:)` using an SF Symbol (baseline: `gauge.with.dots.needle.67percent`; pacing-aware variants may follow in a later refactor). No PNG / `.imageset` / `.icns` asset in the repo; SF Symbols render at native resolution in both light and dark menu bars.
- Launch-at-login toggle wired through `SMAppService.mainApp.register()` / `.unregister()`. The existing spec-level `launch-at-login preference` becomes functional here. UI toggle lives in `SettingsView`.
- First-launch health check that runs once per install (gated by a `UserDefaults` key):
  - Probe write access to `~/Library/Application Support/Pitwall/`.
  - Probe a Keychain round-trip using a disposable test item under a dedicated service name.
  - Log each result through the existing `DiagnosticEventStore`.
  - No network, no upload. User can `File → Export Diagnostics` to surface results.
- Onboarding flow is untouched from Phase 3; returning ClaudeUsage users re-enter `sessionKey` + `lastActiveOrg`. A short "Welcome to Pitwall" banner on first launch explains the clean-room separation and that credentials are not imported.
- No Sparkle, no appcast, no signing cert, no notarytool.

### Acceptance Criteria

- [ ] `make install` succeeds on a clean macOS 13+ system with the project's Swift toolchain installed; produces `/Applications/Pitwall.app` and ad-hoc sign-verifies (`codesign --verify --verbose /Applications/Pitwall.app` exits 0).
- [ ] Double-clicking `Pitwall.app` launches it without a Gatekeeper block because the `.app` was never quarantined (it was built locally, not downloaded).
- [ ] The menu bar shows the SF Symbol icon; clicking it opens the existing Phase 3 popover.
- [ ] `SettingsView` "Launch at Login" toggle flips `SMAppService.mainApp` state; verified by killing the app, rebooting, and confirming Pitwall is running in the menu bar on next login when enabled, not running when disabled.
- [ ] `make uninstall` removes the `.app` and unregisters the login-item; `~/Library/Application Support/Pitwall/` and Keychain items remain untouched (verified via `ls` and `security find-generic-password`).
- [ ] `make install` after `make uninstall` results in state-preserved reinstall (previously-saved session key still present, history still present, settings still present).
- [ ] First-launch health check produces two `DiagnosticEventStore` entries (Application Support write probe + Keychain round-trip probe) and does not repeat on subsequent launches.
- [ ] `CFBundleShortVersionString` and `CFBundleVersion` are derived from `scripts/build-app-bundle.sh` at build time, not hard-coded; version bumps flow from a single source (e.g., `VERSION` file or a `make VERSION=1.0.0` arg).
- [ ] macOS `swift build` + `swift test` still pass at the Phase 5 baseline (193/193) with zero regressions after Phase 6a lands.
- [ ] No new AppKit / UserNotifications / Security imports in `PitwallShared` or platform shells (the privacy fences Phase 5 recorded remain intact).

### Out of Scope for 6a

- Developer ID signing.
- Notarization.
- Sparkle / auto-update.
- DMG build.
- GitHub Releases upload automation.
- Homebrew cask.
- Real `.icns` file or custom brand icon (SF Symbol only).
- Crash log writer beyond what the existing `DiagnosticEventStore` captures.

## Phase 6b: Public Signed Release (deferred, $99/yr)

### Goal

Turn the Phase 6a `.app` into a shareable, signed, notarized, auto-updating DMG on GitHub Releases, plus an optional Homebrew cask.

### Deliverables

- Apple Developer Program enrollment (one-time, user-driven; not an engineering deliverable but a prerequisite).
- Developer ID Application certificate stored in the author's login Keychain.
- `notarytool` credentials stored via `xcrun notarytool store-credentials`, referenced by profile name in the release script.
- `Makefile` target `make release VERSION=x.y.z` that chains:
  1. `swift build --configuration release --product PitwallApp`.
  2. Wrap into `build/Pitwall.app` (reuses the Phase 6a bundle wrapper).
  3. `codesign --sign "Developer ID Application: …" --options runtime --timestamp --deep --force` (hardened runtime on).
  4. Package into `build/Pitwall-<version>.dmg` (`create-dmg` CLI or `hdiutil` + a template; decision defers to `/plan-phase 6b`).
  5. `xcrun notarytool submit build/Pitwall-<version>.dmg --keychain-profile pitwall-notary --wait`.
  6. `xcrun stapler staple build/Pitwall-<version>.dmg`.
  7. Sign the DMG with the Sparkle EdDSA private key → produce `build/Pitwall-<version>.dmg.sig`.
  8. Append a new `<item>` entry to `appcast.xml` with the version, release notes, DMG URL, and EdDSA signature.
  9. `gh release create v<version> build/Pitwall-<version>.dmg build/Pitwall-<version>.dmg.sig --notes-file RELEASE_NOTES.md`.
  10. Publish `appcast.xml` to the hosting URL (GitHub Pages or repo-hosted raw file — decision defers to `/plan-phase 6b`).
- `Sources/PitwallApp/` Sparkle integration:
  - Sparkle 2.x added as a SwiftPM dependency in `Package.swift`.
  - `SUFeedURL`, `SUPublicEDKey` entries added to `Info.plist`.
  - `SPUStandardUpdaterController` wired into `AppDelegate`.
  - A "Check for Updates…" menu item added to the status-bar menu.
  - "Automatically check for updates" and "Check daily/weekly/monthly" options surfaced in `SettingsView`.
- Entitlements file (`Sources/PitwallApp/Pitwall.entitlements`) scoped for hardened runtime + the minimum required entries. No sandbox entitlement.
- Homebrew cask: a cask formula published either in a self-hosted tap (`homebrew-pitwall` repo) or submitted to `homebrew-cask`. Decision defers to `/plan-phase 6b`; either way the cask pins the GitHub Releases DMG URL and the appcast.
- `CLEAN_ROOM.md` update: the Developer ID signature, EdDSA keys, and notarization account are project infrastructure, not ClaudeUsage-derived artifacts; no clean-room boundary change is triggered by 6b.

### Acceptance Criteria

- [ ] `make release VERSION=1.0.0` on a clean tree produces a signed DMG that passes `spctl --assess --type open --context context:primary-signature build/Pitwall-1.0.0.dmg` (Gatekeeper accepts it without user override).
- [ ] `xcrun stapler validate build/Pitwall-1.0.0.dmg` succeeds.
- [ ] Downloading `Pitwall-1.0.0.dmg` from GitHub Releases on a second Mac (i.e., a machine that applies the quarantine xattr) and double-clicking launches Pitwall without any Gatekeeper dialog.
- [ ] Sparkle's `SPUStandardUpdaterController` checks the appcast on launch (and on-demand via the menu item), offers an update when a newer version is published, downloads it, verifies the EdDSA signature, and relaunches into the new version without losing the user's session key, history, or settings.
- [ ] `brew install --cask pitwall` (via self-hosted tap or upstream cask) installs the same DMG into `/Applications/Pitwall.app` and the app launches without Gatekeeper issues.
- [ ] The Phase 6a `make install` and `make uninstall` paths still work alongside `make release` (developers can iterate locally without triggering a signed release).
- [ ] Phase 6a's first-launch health check runs once per install (signed or ad-hoc) — it does not double-fire when Sparkle replaces the bundle in place.
- [ ] No regressions in Phase 1-5 acceptance tests (193/193 or whatever the then-current baseline is) on macOS.
- [ ] Release notes for each version are derived from `tasks/history.md` + a short hand-curated changelog; the release process explicitly does not publish diagnostics, user data, or Keychain content.
- [ ] `Pitwall.app` runs under hardened runtime without any entitlement beyond what the existing Phase 1-5 behavior requires (Keychain access, network client, filesystem read for `~/.codex` / `~/.gemini`). No `com.apple.security.app-sandbox` entry.

### Out of Scope for 6b

- Windows or Linux release pipelines.
- Mac App Store distribution.
- A GUI wrapper around `make release` (the release target remains a shell script).
- Third-party crash reporter or analytics uploader.
- Automated GitHub Actions release runner (remains a post-6b follow-up).

## Accounts, Storage, And Secrets

- **Apple Developer account** (required only for Phase 6b): one Apple ID enrolled in the Apple Developer Program. Cost: $99 USD/year.
- **Developer ID Application certificate** (6b): issued by Apple, installed in the author's login Keychain. Exported `.p12` stored in the author's password manager for disaster recovery.
- **App-specific password for `notarytool`** (6b): generated at appleid.apple.com, stored via `xcrun notarytool store-credentials --apple-id … --team-id … pitwall-notary`. Profile name `pitwall-notary` referenced by the release script. Raw password is never committed.
- **Sparkle EdDSA key pair** (6b): generated with `generate_keys` from the Sparkle distribution. Public key lives in `Info.plist` under `SUPublicEDKey`. Private key stored in the author's password manager only; it never enters the repo, CI, or a committed file.
- **Sparkle appcast hosting** (6b): GitHub Pages (`github.com/<owner>/pitwall` → `docs/appcast.xml` or a `gh-pages` branch). Decision deferred to `/plan-phase 6b`.
- **No user telemetry, analytics, or remote crash report** at any phase. Matches the Phase 1-5 `no analytics upload` non-goal.

## Build / Test Strategy

- Phase 6a tests live in `Tests/PitwallAppSupportTests` where possible (for pure logic like version-string derivation, login-item wrapper protocol) and as a `scripts/smoke-install.sh` shell test that `make install`s into a tmp prefix and verifies the bundle structure.
- Phase 6b adds `scripts/smoke-release.sh` that runs `make release` against a throwaway version number in a tmp prefix, asserts `spctl --assess` passes against the built DMG, and tears down.
- `swift build` + `swift test` remain the functional regression gate; packaging scripts are smoke-tested but are not a replacement for the XCTest suite.
- No GitHub Actions runner; both phases are manual commands on the author's Mac. Real CI is a post-6b follow-up.

## Menu Bar

No change to Phase 3's `NSStatusItem` + SwiftUI popover architecture. Phase 6a only swaps the status-bar image to an SF Symbol and wires version + build number into the About / Settings view. Phase 6b adds a "Check for Updates…" menu item above "Quit."

## Popover

No change. Phase 6a may add a one-line version label in a corner of the popover's footer so users can report bugs against a specific build.

## Settings

Phase 6a additions to `SettingsView`:

- "Launch at Login" toggle wired to `SMAppService.mainApp`.
- "About Pitwall" section with version string, build number, short clean-room attribution, and a link to the GitHub repo.
- `File → Export Diagnostics` is unchanged from Phase 4.

Phase 6b additions to `SettingsView`:

- "Check for Updates…" button.
- "Automatically check for updates" toggle.
- Update cadence picker (daily / weekly / monthly).

## Onboarding

No change to Phase 3's onboarding flow. Phase 6a adds a short one-time banner on the first post-install launch explaining:

- Pitwall is a clean-room rewrite; ClaudeUsage data is not automatically migrated.
- The user should paste their `sessionKey` and `lastActiveOrg` into the Claude account setup view.
- All secrets are stored in the macOS Keychain; nothing is sent to any server other than `claude.ai` for usage data, `api.github.com` for heatmap data, and (in 6b) the Sparkle appcast URL for update checks.

## Notifications

No change to Phase 4 `UserNotificationScheduler`. Phase 6b does not use notifications to announce updates; Sparkle's own UI handles update prompts.

## History

No change to Phase 4 retention. First-install migration does not touch history storage.

## GitHub Heatmap

No change to Phase 4.

## Diagnostics

Phase 6a's first-launch health check writes two events through the existing `DiagnosticEventStore`:

- `packaging.firstLaunch.appSupportWritable` — boolean + error string if it failed.
- `packaging.firstLaunch.keychainRoundTrip` — boolean + error string if it failed.

These events surface through `DiagnosticsExporter` with the existing redaction rules; the probe deliberately writes and deletes a disposable Keychain item rather than touching real provider credentials.

Phase 6b does not add new diagnostic events; Sparkle's own error reporting logs to the system log, not to `DiagnosticEventStore`.

## Verification

Initial implementation should include tests for:

**Phase 6a**:

- Version-string derivation: `CFBundleShortVersionString` matches the `VERSION` file or `make` argument; `CFBundleVersion` matches `git rev-list --count HEAD`.
- Login-item wrapper protocol: a test double verifies `register()` and `unregister()` are called exactly once per toggle flip, without invoking `SMAppService` in unit tests.
- First-launch health-check gating: the probe runs once, records two diagnostic events, and does not re-run on subsequent launches.
- Smoke install test: `scripts/smoke-install.sh` builds, bundles, ad-hoc signs, and `codesign --verify`s the output.
- All Phase 1-5 XCTest cases continue to pass unchanged.

**Phase 6b**:

- Smoke release test: `scripts/smoke-release.sh` produces a signed DMG against a stub notarization credential (or flagged to skip real notarization in CI) and asserts structure + signature verification.
- Appcast entry generator test: the script that appends a new `<item>` to `appcast.xml` produces well-formed XML with a valid EdDSA signature (verified against a test key pair).
- Sparkle integration smoke test: the `Info.plist` contains `SUFeedURL` and `SUPublicEDKey`; `SPUStandardUpdaterController` is constructed without throwing.
- All Phase 1-5 + Phase 6a XCTest cases continue to pass unchanged.

## Open Questions

Phase 6a:

- What is the final SF Symbol? Baseline is `gauge.with.dots.needle.67percent`; alternatives include `gauge.medium`, `chart.bar.xaxis.ascending`, `timer`. Defer to the implementation lane.
- Does the version source live in a `VERSION` file at the repo root or in a single-source-of-truth `Package.swift` constant read by the build script? Defer to `/plan-phase 6a`.

Phase 6b:

- Where does `appcast.xml` live? GitHub Pages on the project repo vs. the `gh-pages` branch vs. a raw-file URL. Defer to `/plan-phase 6b`.
- Self-hosted Homebrew tap (`georgele/homebrew-pitwall`) vs. submission to `homebrew-cask`? Defer to `/plan-phase 6b`.
- DMG template: custom background image with Finder-drop-to-Applications layout, or plain DMG? Defer to `/plan-phase 6b`.
- Code-signing identity rotation: what's the plan when the Developer ID certificate expires? Defer to `/plan-phase 6b`.
- Sparkle update cadence default: daily, weekly, or user-choice-on-first-launch? Defer to `/plan-phase 6b`.
