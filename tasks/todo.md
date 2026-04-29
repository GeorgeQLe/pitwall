# Todo - Pitwall

> Current phase: 6b of 6b — macOS Public Release.
> Source roadmap: `tasks/roadmap.md`
> Project: Pitwall — clean-room macOS menu bar app for Claude/Codex/Gemini usage pacing.

## Priority Documentation Todo

- [ ] `/pack` - decide and record the project pack in `.agents/project.json` because no `.agents/project.json` exists and no project-pack research skills (e.g. `/icp`, `/devtool-user-map`, `/game-audience`) are installed under `~/.claude/skills/`; the research-roadmap skill defaulted to `business-app` inference for a desktop utility, which the user should confirm or override before any pack-scoped research is queued.
- [ ] `/spec-drift fix all` - reconcile `specs/pitwall-macos-clean-room.md` (last modified 2026-04-27 17:45) and `specs/pitwall-macos-packaging.md` (last modified 2026-04-22 13:13) with implementation because there are 14 commits under `Sources/**` since the clean-room spec timestamp and the packaging spec predates Sparkle integration, Info.plist updates, and the Makefile/`build-app-bundle.sh` flow now in tree.
- [ ] `/reconcile-dev-docs` - sweep `tasks/roadmap.md`, `tasks/todo.md`, `tasks/history.md`, and `tasks/phases/` for drift after `/spec-drift` reports; current phase 6b is mid-flight with multiple completed hotfixes that should be confirmed against `tasks/roadmap.md` acceptance criteria before public release.

## Priority Task Queue

- [x] Hotfix: Session-first compact menu bar and popover S:/W: display
  - [x] Reorder `compactMenuBarTitle` to prefer session utilization over `primaryValue`.
  - [x] Extract shared `sessionUtilizationPercent` into `ProviderState+SessionUtilization.swift`.
  - [x] Update popover `ProviderCardViewModel.primaryMetric` to show `S:X% W:Y%` format.
  - [x] Update compact menu bar and provider card tests.
  - [x] Verify all 272 tests pass.

### Review: Session-First Compact Menu Bar

- Result: Compact menu bar titles now consistently show session utilization for all providers (Claude and Codex) instead of inconsistently using weekly-based `primaryValue` for Claude and session-based for Codex. The popover provider card primary metric now shows `S:X% W:Y%` when both session and weekly data are available. Session utilization parsing was extracted into a shared `ProviderState` extension to eliminate duplication between `MenuBarStatusFormatter` and `ProviderCardViewModel`.
- Verification: `swift test` passed 272 / 272 with 0 failures.

- [x] Hotfix: Usage calculation accuracy audit
  - [x] Trace provider usage values through parser, provider state, formatter, card, and history paths.
  - [x] Remove fabricated utilization/reset values from initial app state.
  - [x] Make compact menu-bar titles use canonical provider primary metrics.
  - [x] Align today's usage baseline with the closest retained pre-midnight snapshot.
  - [x] Add focused regression coverage for corrected accuracy paths.
  - [x] Verify focused and full Swift tests pass.

### Review: Usage Calculation Accuracy Audit

- Result: The audit found three accuracy problems: launch state used hardcoded demo utilization/reset values before real configuration/history loaded; compact menu-bar titles silently preferred unlabeled session percentages over the provider's canonical primary metric; and today's usage only accepted a baseline from the immediately previous local day instead of the closest retained snapshot before local midnight. Pitwall now starts from setup placeholders, compact titles match provider-card primary metrics such as Codex session remaining, and daily usage uses the closest retained pre-midnight baseline.
- Verification: `swift test --filter DailyBudgetTests` passed 6 tests; `swift test --filter MenuBarStatusFormatterTests` passed 20 tests; `swift test --filter ProviderStateFactoryTests` passed 7 tests; `swift test` passed 272 tests.

- [x] Hotfix: Compact menu bar title mode
  - [x] Add persisted compact/rich menu bar title preference.
  - [x] Default menu bar titles to compact provider + metric text.
  - [x] Preserve the existing rich multi-segment status when selected.
  - [x] Expose compact/rich selector in Display settings.
  - [x] Verify focused and full Swift tests pass.

### Review: Compact Menu Bar Title Mode

- Result: Pitwall now defaults to compact menu bar titles such as provider plus primary live metric, reducing the chance that macOS hides the item when the menu bar is crowded. Users can switch back to the rich multi-segment title from Display settings. The preference persists through the shared configuration model, onboarding draft storage, and macOS/Windows/Linux Codable settings wrappers.
- Verification: focused formatter/configuration/settings tests passed 31 tests; `swift test` passed 269 tests.

- [x] Hotfix: Shared menu bar usage scheme
  - [x] Trace provider-specific rich menu bar percentage and emoji selection.
  - [x] Use used-percent semantics for rich session quota display across providers.
  - [x] Make tooltip session copy use the same "used" wording across providers.
  - [x] Update focused formatter regression coverage.
  - [x] Verify focused Swift tests pass.

### Review: Shared Menu Bar Usage Scheme

- Result: Rich menu bar titles now render session, daily, and weekly quota percentages as used percentages across Claude, Codex, and Gemini. Codex no longer displays a five-hour remaining percentage beside an emoji derived from five-hour usage; the title and tooltip both use the primary five-hour bucket as used percentage. Codex provider-card primary metrics still retain the session-left summary from provider state.
- Verification: `swift test --filter MenuBarStatusFormatterTests` passed 18 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 15 tests; `swift test` passed 269 tests.

- [x] Hotfix: Codex five-hour session remaining display
  - [x] Trace Codex primary/secondary rate-limit bucket flow into provider state and menu formatter.
  - [x] Make Codex primary visible metric use primary five-hour session remaining.
  - [x] Keep weekly/secondary usage for weekly segment and daily-budget math.
  - [x] Add focused regression coverage for 40% five-hour session remaining with 8% weekly usage.
  - [x] Verify focused Swift tests pass.

### Review: Codex Five-Hour Session Remaining Display

- Result: Codex provider state now exposes the primary five-hour bucket as `session left` for the primary visible metric, and rich menu titles/tooltips display five-hour session remaining instead of weekly used percentage. Weekly/secondary usage remains in the weekly segment and continues to drive daily-budget math.
- Verification: `swift test --filter CodexUsageClientTests` passed 2 tests; `swift test --filter MenuBarStatusFormatterTests` passed 18 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 15 tests; `swift test` passed 269 tests.

- [x] Hotfix: Rich menu bar shows weekly countdown instead of session for Claude
  - [x] Add Claude-specific session reset extraction to `menuBarResetWindow(for:)`.
  - [x] Store ISO8601 session reset date in history path via `SessionResetAt` key.
  - [x] Add regression tests for Claude session countdown in rich menu bar.
  - [x] Verify all tests pass.

### Review: Rich Menu Bar Session Countdown for Claude

- Result: Rich menu bar countdown for Claude now shows the session reset window instead of the weekly reset. `menuBarResetWindow(for:)` gained a Claude-specific branch that extracts the session reset date from the `usageRows` payload — checking `SessionResetAt` key first (history path), then parsing ISO8601 from `Session` encoded value index 1 (live path). The history path now stores `SessionResetAt` as a raw ISO8601 date alongside the pre-formatted Session value.
- Verification: `swift test` passed 275 tests with 0 failures; `make build` succeeded.

- [x] Hotfix: Add periodic auto-refresh timer
  - [x] Add `refreshTimer` property to `MenuBarController`.
  - [x] Add `scheduleRefreshTimer(at:)` one-shot timer method.
  - [x] Wire `applyRefreshOutcome` to schedule next refresh via `outcome.nextClaudeRefreshAt`.
  - [x] Invalidate refresh timer in `stop()`.
  - [x] Verify all tests pass.

### Review: Periodic Auto-Refresh Timer

- Result: Usage data now auto-refreshes on the interval computed by `PollingPolicy` (~5 minutes). `MenuBarController` schedules a one-shot timer from `ProviderRefreshOutcome.nextClaudeRefreshAt` after every refresh. The loop is self-sustaining: each `applyRefreshOutcome` schedules the next timer, and manual refreshes replace the pending timer. No changes to `PollingPolicy` or `ProviderRefreshCoordinator`.
- Verification: `swift test` passed 275 tests with 0 failures.

- [x] Hotfix: Claude menu bar pace theme indicators
  - [x] Trace rich formatter icon selection for Claude session, daily, and weekly pace.
  - [x] Use pace-aware status for daily `today/target/day` indicators.
  - [x] Add focused regression coverage for behind/way-behind F1 theme output.
  - [x] Verify focused Swift tests pass.

### Review: Claude Menu Bar Pace Theme Indicators

- Result: Rich menu bar daily `today/target/day` indicators now use the same pace status mapping as session and weekly indicators when both actual usage and target are known. The F1 theme now renders far-behind pace as a black circle instead of a neutral/on-track purple circle, while high burn still uses alert colors.
- Verification: `swift test --filter MenuBarStatusFormatterTests` passed 17 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 15 tests; `swift test` passed 268 tests.

- [ ] Hotfix: Gemini passive configuration detection
  - [x] Trace Gemini passive detection and provider refresh behavior.
  - [x] Require OAuth cache evidence before reporting Gemini as configured.
  - [x] Add regression coverage for settings-only Gemini snapshots.
  - [x] Verify focused Swift tests pass.

### Review: Gemini Passive Configuration Detection Hotfix

- Result: Gemini passive detection now requires both settings and `oauth_creds.json` evidence before reporting `.configured`. Settings-only Gemini snapshots still preserve sanitized auth/profile/activity evidence, but now report "Gemini login not detected" and stay out of tracked menu-bar rotation.
- Verification: `swift test --filter ProviderDetectionTests` passed 6 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 14 tests; `swift test --filter PitwallAppSupportTests` passed 100 tests; `swift test` passed 261 tests.

- Follow-up result: Auth-backed but quota-empty Gemini states are no longer considered live menu-bar rotation candidates. `trackedProviders` now requires configured providers to have displayable quota/pacing/reset/primary data, preventing "Gemini estimated configure" from appearing in the top menu bar when Gemini has no usable usage information.
- Follow-up verification: `swift test --filter ProviderStateFactoryTests` passed 7 tests; `swift test --filter MenuBarStatusFormatterTests` passed 13 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 15 tests; `swift test --filter ProviderRotationControllerTests` passed 7 tests; `swift test --filter PitwallAppSupportTests` passed 103 tests; `swift test` passed 264 tests.

- [x] Hotfix: Codex slash status/menu bar alignment
  - [x] Trace slash status data fields and menu bar formatter fields.
  - [x] Patch the narrowest data-selection mismatch.
  - [x] Add regression coverage for Codex menu bar alignment.
  - [x] Verify focused Swift tests pass.

### Review: Codex Slash Status/Menu Bar Alignment Hotfix

- Result: Codex provider refresh now treats the top-level app-server `rateLimits` payload as canonical, matching the slash-status-style response, instead of preferring a possibly divergent nested `rateLimitsByLimitId["codex"]` bucket. The menu bar continues to derive session, weekly, and reset text from that selected provider state.
- Verification: `swift test --filter CodexUsageClientTests` passed 2 tests; `swift test --filter ProviderRefreshCoordinatorTests` passed 13 tests; `swift test --filter MenuBarStatusFormatterTests` passed 12 tests.

- [x] Hotfix: Gemini CLI quota telemetry
  - [x] Add an opt-in Gemini CLI quota client for Google-login credentials.
  - [x] Integrate provider-supplied Gemini quota into refresh state and history.
  - [x] Add Settings UI for Gemini telemetry enablement and status.
  - [x] Add focused parsing/coordinator/UI coverage.
  - [x] Verify focused Swift tests pass.

### Review: Gemini CLI Quota Telemetry

- Result: Gemini can now opt in to provider-supplied quota telemetry using the existing Gemini CLI Google-login cache. Successful quota refreshes upgrade Gemini to provider-supplied state, write sanitized history snapshots, and keep passive local evidence as the fallback on unsupported modes or API failure.
- Verification: `swift test --filter PitwallAppSupportTests` passed 97 tests with 0 failures; `swift test` passed 257 tests with 0 failures.

- [x] Hotfix: Settings controller lifetime
  - [x] Keep Settings callbacks backed by a live menu bar controller while the Settings window is open.
  - [x] Clear Settings SwiftUI content and callbacks when the Settings window closes.
  - [x] Verify focused Swift tests pass.

### Review: Settings Controller Lifetime Hotfix

- Result: Settings save/test callbacks now retain the menu bar controller for the visible Settings window lifetime, and the Settings window clears its hosted SwiftUI content on close so the retain path is released.
- Verification: `swift build` passed; `swift test --filter PitwallAppSupportTests` passed 92 tests with 0 failures.

- [x] Hotfix: Settings provider enablement cleanup
  - [x] Simplify the generic provider list to visible/skipped control only.
  - [x] Keep Codex auth mode and plan/profile in the dedicated Codex Connection section.
  - [x] Preserve stored provider profile fields for compatibility.
  - [x] Verify focused Swift tests pass.

### Review: Settings Provider Enablement Cleanup

- Result: The generic Providers settings section now only controls whether Claude, Codex, and Gemini are visible/skipped. Codex auth mode and plan/profile remain in the dedicated Codex Connection section, and stored provider profile fields are unchanged for compatibility.
- Verification: `swift test --filter ProviderConfigurationStoreTests` passed 10 tests with 0 failures; `swift test --filter ProviderStateFactoryTests` passed 6 tests with 0 failures; `swift test --filter PitwallAppSupportTests` passed 92 tests with 0 failures.

- [x] Hotfix: Ticking menu bar countdowns for all providers
  - [x] Add seconds-capable countdown formatting for menu bar titles.
  - [x] Apply seconds countdowns consistently to Claude, Codex, and Gemini menu bar titles.
  - [x] Refresh the status item title every second.
  - [x] Verify focused Swift tests pass.

### Review: Ticking Menu Bar Countdown Hotfix

- Result: Claude, Codex, and Gemini menu bar title countdowns now include seconds. The existing one-second timer now recomputes the status item title on every tick, so the countdown visibly updates.
- Verification: `swift test --filter MenuBarStatusFormatterTests` passed 12 tests with 0 failures; `swift test --filter PitwallAppSupportTests` passed 92 tests with 0 failures.

- [x] Hotfix: Codex menu bar 5-hour countdown
  - [x] Keep Codex weekly reset available for weekly budget/card context.
  - [x] Make rich menu bar formatting prefer Codex primary/session reset for compact countdown.
  - [x] Add regression coverage for Codex primary/session countdown.
  - [x] Verify focused Swift tests pass.

### Review: Codex Menu Bar 5-Hour Countdown Hotfix

- Result: Codex rich menu bar titles now prefer the primary/session rate-limit reset from `codex-rate-limits.primary` for the compact countdown, while the provider-level reset remains weekly-first for weekly budget and card context.
- Verification: `swift test --filter MenuBarStatusFormatterTests` passed 11 tests with 0 failures; `swift test --filter PitwallAppSupportTests` passed 91 tests with 0 failures.

- [x] Hotfix: Codex today target baseline
  - [x] Persist provider-supplied Codex telemetry snapshots to provider history.
  - [x] Use retained Codex snapshots when computing daily usage and target.
  - [x] Add regression coverage for Codex `today/target/day` display after a baseline exists.
  - [x] Verify focused Swift tests pass.

### Review: Codex Today Target Baseline Hotfix

- Result: Codex provider-supplied telemetry now writes sanitized history snapshots and uses retained Codex weekly usage snapshots when calculating daily budget. After Pitwall has a same-day or prior-day Codex baseline, the menu bar can show `today/target/day` for Codex just like Claude.
- Verification: `swift test --filter ProviderRefreshCoordinatorTests` passed 10 tests with 0 failures; `swift test --filter PitwallAppSupportTests` passed 90 tests with 0 failures.

- [x] Hotfix: Top menu bar provider parity
  - [x] Refactor menu bar title derivation so configured Claude and Codex can use the same rich quota formatter.
  - [x] Preserve Claude session-row parsing while deriving Codex session data from provider-supplied pacing/rate-limit state.
  - [x] Add regression coverage for Codex themed menu bar parity and unchanged Claude output.
  - [x] Verify focused Swift tests pass.

### Review: Top Menu Bar Provider Parity Hotfix

- Result: configured providers now share the same rich menu bar title derivation when they expose structured quota data. Claude continues to use its usage-row session percent, while Codex derives session percent from provider-supplied `codex-rate-limits` primary window payloads and uses the same theme/status mapping.
- Verification: `swift test --filter MenuBarStatusFormatterTests` passed 10 tests with 0 failures; `swift test --filter PitwallAppSupportTests` passed 89 tests with 0 failures.

- [x] Hotfix: Hide unconfigured providers from tracked rotation and popover
  - [x] Add a shared configured-provider projection for status/menu/popover surfaces.
  - [x] Ensure automatic rotation, selected-provider fallback, popover cards, and provider switching use only properly configured providers.
  - [x] Add regression coverage for single-configured-provider rotation and hidden placeholder cards.
  - [x] Verify focused Swift tests pass.

### Review: Configured Provider Tracking Hotfix

- Result: tracked menu-bar rotation and popover cards now use only providers with `status == .configured`; missing/expired setup placeholders remain available through settings/onboarding but no longer show as live retrieved data.
- Verification: `swift test --filter PitwallAppSupportTests` passed 88 tests with 0 failures.
- [x] `/run` — execute Phase 6b Step 6b.1 (Sparkle 2.x dependency, entitlements, Info.plist keys, build script updates).
- [x] `/run` — execute Phase 6b Step 6b.2 (wire Sparkle updater into AppDelegate and Settings UI).
- [x] `/run` — execute Phase 6b Step 6b.3 (create release automation script).
- [x] `/run` — execute Phase 6b Step 6b.4 (Makefile release target and appcast.xml template).
- [x] `/run` — execute Phase 6b Step 6b.5 (Homebrew cask formula).
- [ ] `/guide` — complete Phase 6b manual prerequisites (Apple Developer enrollment, Developer ID cert, notarytool creds, Sparkle EdDSA key, appcast hosting, Homebrew tap). See `tasks/manual-todo.md`.
- [ ] `/run` — execute Phase 6b Step 6b.6 (fill in real Sparkle keys and appcast URL from completed prerequisites).
- [ ] `/run` — execute Phase 6b Step 6b.7 (regression tests for Sparkle integration and release pipeline).
- [ ] `/run` — execute Phase 6b Step 6b.8 (end-to-end release validation). Blocked on all manual prerequisites.
- [ ] `/run` — execute Phase 6b Step 6b.9 (refactor if needed while keeping tests green).
- [ ] `/plan-phase 7` — Claude Code credential adoption: read OAuth tokens from `Claude Code-credentials` keychain item, query `api.anthropic.com/api/oauth/{profile,usage}` so onboarding requires zero sessionKey paste when Claude Code is installed. Manual sessionKey path stays as fallback. See `tasks/roadmap.md` → Phase 7.

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

- [x] Step 6b.5: Create Homebrew cask formula
  - Files: created `Casks/pitwall.rb` (Homebrew cask pointing to the GitHub Releases DMG URL pattern `https://github.com/GeorgeQLe/pitwall/releases/download/v#{version}/Pitwall-#{version}.dmg`; `sha256 :no_check` placeholder until the first real release SHA256 is available; `app "Pitwall.app"`). Note: the original plan said `Formula/pitwall.rb`, but casks belong under `Casks/` in a Homebrew tap.
  - Documented in `README.md` the planned self-hosted tap install path: `brew tap georgele/pitwall && brew install --cask pitwall`. The tap/release remains blocked on manual-todo resolution.

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

## Code Review Fixes
> Generated by `/expert-review` on 2026-04-29
### High
- [x] [Sources/PitwallAppSupport/GeminiUsageClient.swift:438-439] — `escape()` uses `.urlQueryAllowed` which does not encode `&`, `=`, `+`; replace with a custom `CharacterSet` of RFC 3986 unreserved characters for correct `application/x-www-form-urlencoded` encoding.
- [x] [Sources/PitwallAppSupport/CodexUsageClient.swift:357-368] — NSLock in `CodexAppServerLineReader.append()` and `CodexLockedDataBuffer.append()` (line 380-383) not protected by `defer`; add `defer { lock.unlock() }` to prevent deadlock on trap.
- [x] [Sources/PitwallWindows/WindowsStatusFormatter.swift:139] and [Sources/PitwallLinux/LinuxStatusFormatter.swift:139] — `recommendedAction()` falls through to `.configure` for healthy providers without weekly pacing; return a neutral/appropriate action instead. Also fixed in macOS `MenuBarStatusFormatter.swift`.
- [x] [Sources/PitwallAppSupport/GeminiUsageClient.swift:416] — `dateValue()` allocates a new `ISO8601DateFormatter` per call; use a `static let` cached formatter.

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
