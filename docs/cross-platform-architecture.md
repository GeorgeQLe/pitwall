# Pitwall Cross-Platform Architecture Decision

This document records the Phase 5 Step 5.1 decision for how Pitwall reaches Windows/Linux parity without disturbing the macOS v1 implementation or the clean-room constraints recorded in `CLEAN_ROOM.md` and `specs/pitwall-macos-clean-room.md`.

It is a planning artifact. Downstream Phase 5 steps (5.2 through 5.5) will reference the sections below when they extract shared contracts, build platform shells, and add platform-specific Codex/Gemini detection adapters.

## Chosen Approach

Pitwall stays **SwiftPM-first with platform-specific shell targets**. We do **not** adopt a non-Swift UI runtime (Electron, Tauri, Flutter, etc.) for v1 cross-platform parity.

Rationale:

- `PitwallCore` already holds all portable domain logic for pacing, Claude parsing, provider confidence, local detector evidence, history retention, diagnostics redaction, and GitHub heatmap request/response mapping. Introducing a second runtime would force a translation layer across that portable logic for no behavioral gain.
- Swift compiles on Windows and Linux through the official open-source Swift toolchain, so one language can host the shared module and each platform shell.
- Clean-room rules forbid mechanical translation from upstream ClaudeUsage sources. Keeping Swift and re-implementing only the shell (tray/menu, storage, notification scheduling) keeps every cross-platform change derivable from the repository specs and public platform docs, instead of from a ported UI layer.
- The existing macOS `PitwallApp` AppKit shell, `PitwallAppSupport` coordination code, and `PitwallCore` tests remain untouched; the cross-platform effort grows sideways from `PitwallCore`, not through a rewrite.

Trade-offs accepted:

- Swift on Windows still has sharper edges than Swift on Apple platforms (toolchain availability, WinSDK bindings, notarization tooling). The architecture absorbs that cost because retaining portable domain logic is more valuable than picking a more mature cross-platform UI runtime.
- Some platform UI chrome will look less uniform than a single-runtime approach because each shell uses native controls. That is intentional: menu bar / tray apps are expected to feel native per OS.

## Module Layout

Today the package has three targets: `PitwallCore`, `PitwallAppSupport`, and `PitwallApp`. Cross-platform parity grows this set carefully.

- `PitwallCore` remains the canonical shared module. All portable domain logic continues to live here. No duplicate shared module is introduced unless Step 5.2 discovers portable logic currently trapped inside `PitwallAppSupport`.
- `PitwallAppSupport` stays macOS-only by default. Its current contents include macOS-adjacent coordination (AppKit-facing view models, notification scheduling tied to `UserNotifications`, menu bar status formatter consumed by the AppKit shell, file-backed stores that assume Application Support paths, etc.).
- A future `PitwallShared` target is **conditional**. It is only created in Step 5.2 if and only if Step 5.2's audit of `PitwallAppSupport` finds logic that is both (a) cross-platform-worthy and (b) not already located in `PitwallCore`. Candidates include the pure parts of `NotificationPolicy`, `PollingPolicy`, `MenuBarStatusFormatter`, `ProviderRotationController`, `ProviderCardViewModel`, and the redaction/retention glue pieces that only pull from `Foundation`. If every candidate is already pure enough to live in `PitwallCore`, Step 5.2 will promote it into `PitwallCore` instead of creating `PitwallShared`. This avoids speculative targets.
- Steps 5.3 and 5.4 add sibling shell targets: `PitwallWindowsSupport` + `PitwallWindows` (Windows shell) and `PitwallLinuxSupport` + `PitwallLinux` (Linux shell). They depend on `PitwallCore` (and `PitwallShared` if it exists by then) and do **not** depend on `PitwallAppSupport`.
- `PitwallApp` continues to depend on `PitwallAppSupport` + `PitwallCore`. It does not consume the Windows/Linux support targets.

## Adapter Seams

Platform shells plug into `PitwallCore` through narrow protocol seams. Some already exist in the tree; others are called out as work for Step 5.2.

### Existing Seams

- `ProviderSecretStore` (in `Sources/PitwallCore/SecretStore.swift`). Abstract async protocol with `save`, `loadSecret`, `deleteSecret`. The macOS implementation (`KeychainSecretStore`) backs it with the Security framework. Windows and Linux get their own implementations:
  - **macOS**: existing `KeychainSecretStore` (Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
  - **Windows**: a new Credential Manager-backed store using `CredWriteW` / `CredReadW` / `CredDeleteW` from `Advapi32`. Secrets land in the user's Windows credential vault, tied to the same `ProviderSecretKey` shape (`providerId:accountId:purpose`).
  - **Linux**: a new `libsecret`-backed store using the Secret Service API (GNOME Keyring, KWallet, or other Secret Service provider). The implementation must document an explicit fallback behavior for environments where `libsecret` / Secret Service is unavailable: surface a `missing`-equivalent state and refuse to persist Claude / GitHub tokens, rather than silently writing to a less-secure location.
- `NotificationScheduling` (in `Sources/PitwallAppSupport/NotificationScheduler.swift`). The policy/decision logic (`NotificationPolicy`, `NotificationPreferences`) is pure and already testable without OS permission. Per-platform schedulers implement the scheduling protocol:
  - **macOS**: existing `UserNotifications`-backed scheduler.
  - **Windows**: a toast-notification scheduler using WinRT `ToastNotificationManager` (or the equivalent WinAppSDK surface chosen by the Windows shell lane).
  - **Linux**: a `libnotify` / `org.freedesktop.Notifications` D-Bus scheduler, with an explicit fallback to a suppressed state when the session bus cannot be reached.

### Seams To Extract In Step 5.2

The following protocols do not yet exist; they are scheduled for extraction in Step 5.2 because the current implementations mix pure logic with macOS assumptions. They are named here so the Windows and Linux lanes know what surface to expect.

- `ProviderConfigurationStorage` — hides the on-disk layout for non-secret account metadata (Claude org ids, account labels, provider enablement). Today it lives behind `Sources/PitwallAppSupport/ProviderConfigurationStore.swift` and assumes Application Support paths. Platform implementations must resolve:
  - **macOS**: `~/Library/Application Support/Pitwall/` (Application Support directory).
  - **Windows**: `%APPDATA%\Pitwall\` (roaming) with an explicit note that the chosen Windows shell scope may instead use `%LOCALAPPDATA%\Pitwall\` if cross-device roaming is undesirable; Step 5.3 records the final choice.
  - **Linux**: XDG Base Directory, i.e. `$XDG_CONFIG_HOME/pitwall/` or `~/.config/pitwall/` for configuration and `$XDG_DATA_HOME/pitwall/` or `~/.local/share/pitwall/` for derived data.
- `ProviderHistoryStorage` — hides how retained/downsampled snapshots from `ProviderHistoryRetention` are persisted. Same per-platform path rules apply; snapshots remain derived-only (no raw responses, tokens, prompts, or cookies, per Phase 4).
- `SettingsStorage` — hides the current `UserDefaults` / app-support hybrid for history, diagnostics, notification, and GitHub heatmap non-secret preferences. Windows implementation likely uses a JSON blob under `%APPDATA%\Pitwall\`; Linux uses an equivalent file under `$XDG_CONFIG_HOME/pitwall/`. `UserDefaults` remains the macOS-only backing.

These three protocols replace direct `FileManager` + `NSSearchPathForDirectoriesInDomains` usage at the `PitwallAppSupport` boundary so no shell target has to re-discover where to write data.

### Tray / Menu UI

The tray / menu surface is inherently platform-specific and is **not** extracted into a shared protocol at the behavior level. Each shell provides its own tray implementation against the shared view-model types.

- **macOS**: continues to use AppKit `NSStatusItem` and the existing `PitwallApp` shell.
- **Windows**: uses a native tray. The shell lane chooses between Win32 `Shell_NotifyIcon` directly (lowest dependency) and a Swift binding to a higher-level toolkit (Swift-WinUI / WinAppSDK) when Step 5.3 finalizes its toolkit decision. Either way, the tray surface consumes `MenuBarStatusFormatter`-shaped view models, not platform-specific formatting.
- **Linux**: uses `AppIndicator` / `libayatana-appindicator`. Because many modern desktop environments no longer expose system tray support by default, the Linux shell must document an explicit fallback (for example, surfacing the popover as a windowed app) rather than silently disappearing. Step 5.4 records the final fallback.

## Privacy Guardrails Per Platform

The Phase 1-4 privacy model applies **identically** on Windows and Linux. Restating it here so downstream lanes cannot quietly weaken it:

- Claude credentials remain manual-entry only. No browser cookie extraction on any platform. The onboarding flow on every shell must keep the `sessionKey` / `lastActiveOrg` input write-only after save, exactly like the macOS shell.
- Codex and Gemini detection stays presence-only with sanitized evidence. Reading `auth.json` or `oauth_creds.json` is limited to presence + modification-time style signals; token contents are never serialized; `history.jsonl`, `sessions/...`, and `tmp/**/chats/session-*.json` never produce prompt or response text into any persisted snapshot.
- Diagnostics redaction applies identically. `DiagnosticsRedactor` in `PitwallCore` is the single source of truth for what gets scrubbed before persistence or export; platform shells must not bypass it to surface unredacted content.
- GitHub personal access tokens go through `ProviderSecretStore` on every platform. Tokens are never rendered back into UI state after save. 401 / 403 responses map to the invalid-token state the Phase 4 coordinator already models.
- Any platform fallback (for example, Linux without Secret Service) must refuse to store saved secrets rather than silently writing them to a less-secure location. The fallback state must be user-visible.

## Build / Test Strategy

- `swift test` + `swift build` on macOS remains the regression gate. Nothing in Step 5.1 changes that; the same commands continue to cover `PitwallCore` + `PitwallAppSupport` + `PitwallApp`.
- Windows and Linux shells land behind conditional SwiftPM targets. Step 5.2 / 5.3 / 5.4 will apply `.when(platforms:)` filters to sibling `.target(...)` / `.executableTarget(...)` entries so the shells only compile on the platforms they target, while a single `Package.swift` stays the source of truth.
- Shared behavior tests (the Phase 1-4 `PitwallCoreTests` suite plus any `PitwallSharedTests` that Step 5.2 adds) must run on every supported platform. Platform-specific tests live in the platform's own test target.
- If toolchain constraints later force Pitwall to split into multiple SwiftPM manifests (for example, a dedicated manifest for the WinAppSDK bindings), that trade-off must be recorded in this document at that time. We do not pre-emptively commit to that split.

## Windows Shell Stack (Step 5.3)

Recorded when Phase 5 Step 5.3 landed the `PitwallWindows` SwiftPM target:

- **Tray / menu rendering**: Win32 `Shell_NotifyIcon` is the chosen surface. The current landing ships only the portable, AppKit-free view-model types (`WindowsStatusFormatter`, `WindowsProviderCardViewModel`, `WindowsTrayMenuViewModel`, `WindowsTrayMenuBuilder`) so the tray glue can be added in a follow-up without reshaping the shared view-model contract. We did **not** adopt WinAppSDK / Swift-WinUI in Step 5.3 because that path would pull in additional package and licensing review that Step 5.3 was not scoped for.
- **Notification delivery**: `PitwallShared.NotificationScheduling` is implemented by `WindowsNotificationScheduler`, which routes accepted requests through a narrow `WindowsToastDelivering` backend. Production will wrap a WinRT `ToastNotificationManager` call; `WindowsToastSuppressedBackend` is the documented fallback when WinRT bindings are unavailable (the shell must surface the degraded state in its settings UI rather than silently pretending toasts shipped).
- **Credential storage**: `WindowsCredentialManagerSecretStore` conforms to `PitwallCore.ProviderSecretStore` via a narrow `WindowsCredentialManagerBackend` seam. Production wires `CredWriteW` / `CredReadW` / `CredDeleteW` from `Advapi32`; `InMemoryWindowsCredentialBackend` is the test stub. Writes fail closed when the backend is disabled (`WindowsCredentialManagerError.backendUnavailable`) — there is no degraded "remember in memory" fallback.
- **Storage layout**: file-backed JSON under `%APPDATA%\Pitwall\` via `WindowsStorageRoot`. The resolver takes an injected root directory instead of reading `%APPDATA%` inside the protocol, so tests write to a tmp dir and production can pick roaming vs. local without changing the adapter contract. Filenames: `provider-configuration.v1.json`, `provider-history.v1.json`, `settings.v1.json`, and `pitwall-diagnostics.json` for the redacted export.
- **Dependencies / licensing**: no new SwiftPM or system dependencies are introduced by Step 5.3. The Win32 `Advapi32` / `Shell_NotifyIcon` / WinRT `ToastNotificationManager` bindings ship with the Windows SDK; they will be wired via Swift `@_silgen_name` / `windows-rs`-equivalent seams in a follow-up packaging step. If either seam is swapped for a third-party binding, the dependency and its license must be recorded here before merge.
- **CI gap (recorded, not resolved)**: no Windows CI host is configured yet. `swift build --triple x86_64-unknown-windows-msvc` and `swift test` on a real Windows toolchain are not part of the regression gate. Because every Windows adapter is pure Foundation, macOS `swift test` currently runs `PitwallWindowsTests` as a portability proxy. Wiring the real Win32 / WinRT bindings + a Windows CI runner is a known follow-up; until then, Step 5.3 is shipped with "validated cross-platform via macOS proxy" status.

## Linux Shell Stack (Step 5.4)

Recorded when Phase 5 Step 5.4 landed the `PitwallLinux` SwiftPM target:

- **Tray / menu rendering**: `AppIndicator` / `libayatana-appindicator` is the chosen surface. The current landing ships only the portable, AppKit-free view-model types (`LinuxStatusFormatter`, `LinuxProviderCardViewModel`, `LinuxTrayMenuViewModel`, `LinuxTrayMenuBuilder`) so the indicator glue can be added in a follow-up without reshaping the shared view-model contract. Desktop environments without indicator support (stock GNOME, some Wayland sessions) will instead surface the popover as a windowed app; the "no tray available" fallback is documented here as a binding decision and must present the same provider card content without silently dropping the tray surface.
- **Notification delivery**: `PitwallShared.NotificationScheduling` is implemented by `LinuxNotificationScheduler`, which routes accepted requests through a narrow `LinuxNotificationDelivering` backend. Production will wrap `libnotify` / the `org.freedesktop.Notifications` D-Bus interface; `LinuxNotificationSuppressedBackend` is the documented fallback when the session bus is not reachable (headless / container sessions). The suppressed backend must not raise a user-visible error; the shell surfaces the degraded state in its settings UI rather than silently pretending notifications shipped.
- **Credential storage**: `LinuxSecretServiceStore` conforms to `PitwallCore.ProviderSecretStore` via a narrow `LinuxSecretServiceBackend` seam. Production wires `libsecret` / the Secret Service API; `InMemoryLinuxSecretBackend` is the test stub. Writes fail closed when the backend is disabled (`LinuxSecretServiceError.backendUnavailable`) and reads return `nil` rather than a degraded default — there is no plaintext file fallback. When Secret Service is unavailable, the settings UI must show a "Secure storage unavailable — sign-in disabled" banner rather than persisting Claude / GitHub tokens to a less-secure location.
- **Storage layout**: file-backed JSON under `$XDG_CONFIG_HOME/pitwall/` (with `~/.config/pitwall/` fallback) for configuration and settings, and `$XDG_DATA_HOME/pitwall/` (with `~/.local/share/pitwall/` fallback) for history and diagnostics, via `LinuxStorageRoot`. Path resolution honors env overrides only at the shell boundary — the protocol takes an already-resolved root directory, so tests write to a tmp dir and production can pick XDG or fallback without changing the adapter contract. Filenames: `provider-configuration.v1.json`, `provider-history.v1.json`, `settings.v1.json`, and `pitwall-diagnostics.json` for the redacted export.
- **Dependencies / licensing**: no new SwiftPM or system dependencies are introduced by Step 5.4. The `libsecret`, `libnotify`, and `libayatana-appindicator` bindings are wired via narrow C-interop seams in a follow-up packaging step; if any seam is swapped for a third-party binding, the dependency and its license must be recorded here before merge.
- **CI gap (recorded, not resolved)**: no Linux CI host is configured yet. `swift build` + `swift test` on a real Linux toolchain are not part of the regression gate. Because every Linux adapter is pure Foundation, macOS `swift test` currently runs `PitwallLinuxTests` as a portability proxy (mirroring the Step 5.3 Windows approach). Wiring the real `libsecret` / `libnotify` / `libayatana-appindicator` bindings + a Linux CI runner is a known follow-up; until then, Step 5.4 is shipped with "validated cross-platform via macOS proxy" status.

## Codex/Gemini Passive Detection (Step 5.5)

Recorded when Phase 5 Step 5.5 landed the platform-specific Codex/Gemini passive detection adapters under `PitwallWindows` and `PitwallLinux`:

- **Contract**: both platforms expose per-provider detectors (`WindowsCodexDetector`, `WindowsGeminiDetector`, `LinuxCodexDetector`, `LinuxGeminiDetector`) that return sanitized, presence-only evidence. The adapters never read file contents — only existence, byte size, and modification time (seconds since epoch) are surfaced. Token bytes never enter memory.
- **Seam shape**: each detector takes an injected root (mirroring `WindowsStorageRoot` / `LinuxStorageRoot`) and a narrow filesystem probe protocol (`WindowsCodexFilesystemProbing`, `WindowsGeminiFilesystemProbing`, `LinuxCodexFilesystemProbing`, `LinuxGeminiFilesystemProbing`). Production implementations (filesystem readers backed by `FileManager` / Win32 attribute APIs) land in a follow-up packaging step. Tests inject fixture probes that return pre-canned metadata without touching real user directories.
- **Suppressed fallbacks**: when the data root is inaccessible (locked profile, restricted container, unreadable permissions), the detector returns `suppressed: true` evidence with empty artifacts via `WindowsCodexSuppressedProbe` / `WindowsGeminiSuppressedProbe` / `LinuxCodexSuppressedProbe` / `LinuxGeminiSuppressedProbe`. The shell must surface the degraded state — it must not fabricate evidence.
- **Sanitization**: returned `relativePath` fields are pinned to the caller-supplied name, so a malicious or misconfigured probe cannot echo absolute paths or token-shaped substrings back through the detector. Byte sizes are clamped to non-negative values.
- **Windows path map**:
  - Codex: `%APPDATA%\Codex\` — user-level artifacts (`config.toml`, `auth.json`, `history.jsonl`) plus the `sessions\` and `logs\` directories are in the roaming profile. `%LOCALAPPDATA%` is not used; Codex's CLI writes its identity and history under the roaming user profile.
  - Gemini: `%APPDATA%\Gemini\` — `settings.json`, `oauth_creds.json`, and `tmp\**\chats\session-*.json` are in the roaming profile for the same reason.
- **Linux path map**:
  - Codex: `$XDG_CONFIG_HOME/codex/` with `~/.config/codex/` fallback. `$XDG_DATA_HOME` is not used: all Codex user-level artifacts live under `$XDG_CONFIG_HOME`. XDG env overrides are honored only at the shell boundary; the detector protocol takes an already-resolved root.
  - Gemini: `$XDG_CONFIG_HOME/gemini/` with `~/.config/gemini/` fallback, same contract.
- **Unsupported metadata sources (recorded, not resolved)**: neither platform currently exposes per-session token counts or rate-limit evidence beyond presence + size + mtime. Parsing `tmp/**/chats/session-*.json` for `tokenCount` (the macOS `GeminiLocalDetector` behavior) and scanning `logs/` for rate-limit hints (the macOS `CodexLocalDetector` behavior) requires reading file bytes, which is out of scope for Step 5.5's presence-only contract. A Step 5.6+ follow-up may add opt-in metadata extraction behind a documented prompt-safe reader.
- **CI gap (recorded, not resolved)**: as with 5.3 / 5.4, there is no Windows / Linux CI host yet. Because the detectors are pure Foundation, macOS `swift test` exercises both suites as a portability proxy. Wiring real Windows `FindFirstFileW` / Linux `stat(2)` bindings + platform CI runners is a known follow-up.

## Cross-Platform Regression Coverage (Step 5.6)

Recorded when Phase 5 Step 5.6 landed the tests-only cross-platform regression suites. The acceptance bullets from the Phase 5 milestone map to the following suites:

- **Provider visibility parity (Claude/Codex/Gemini enable + selection; disabled providers never reach the tray view model)**:
  - `Tests/PitwallWindowsTests/WindowsCrossPlatformRegressionTests.swift::test_providerVisibility_roundTripAndDisabledProviderIsHidden`
  - `Tests/PitwallLinuxTests/LinuxCrossPlatformRegressionTests.swift::test_providerVisibility_roundTripAndDisabledProviderIsHidden`
  - Shared-layer anchor: `Tests/PitwallSharedTests/CrossPlatformRegressionTests.swift::test_providerVisibility_disabledProvidersDoNotReachViewModel`
- **Tray/menu formatting parity (`WindowsStatusFormatter` and `LinuxStatusFormatter` emit byte-identical tooltips + card labels for the shared fixture)**:
  - `WindowsCrossPlatformRegressionTests::test_statusFormatter_matchesSharedExpectedStrings` + `::test_trayBuilder_emitsCardsMatchingSharedExpectedLabels`
  - `LinuxCrossPlatformRegressionTests::test_statusFormatter_matchesSharedExpectedStrings` + `::test_trayBuilder_emitsCardsMatchingSharedExpectedLabels`
  - Parity is enforced by hard-coding the same `Expected` string constants in both platform suites; drift on either side fails the sibling test.
- **Credential write-only behavior + secure-storage fallback enum (no plaintext read path; writes throw `backendUnavailable`; reads return `nil`; no silent on-disk fallback)**:
  - `WindowsCrossPlatformRegressionTests::test_credentialStore_neverExposesPlaintextReadPath_onFailingBackend` + `::test_secureStorageDegradedStateEnum_isVisibleToShell`
  - `LinuxCrossPlatformRegressionTests::test_credentialStore_neverExposesPlaintextReadPath_onFailingBackend` + `::test_secureStorageDegradedStateEnum_isVisibleToShell`
- **Codex/Gemini sanitization (no absolute path, no token-shaped substring `sk-…` / `ghp_…` / `ya29.…` / `AIza…`, no file-content bytes in returned evidence)**:
  - `WindowsCrossPlatformRegressionTests::test_codexDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings` + `::test_geminiDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings` + `::test_detectors_suppressedWhenProbeUnavailable_noFabricatedEvidence`
  - `LinuxCrossPlatformRegressionTests::test_codexDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings` + `::test_geminiDetector_sanitizesAbsolutePathsAndTokenShapedSubstrings` + `::test_detectors_suppressedWhenProbeUnavailable_noFabricatedEvidence`
- **Diagnostics redaction parity (`WindowsDiagnosticsExporter` + `LinuxDiagnosticsExporter` emit the same redacted key set via the shared `DiagnosticsRedactor` for the same `DiagnosticsInput` fixture)**:
  - `WindowsCrossPlatformRegressionTests::test_diagnosticsExport_redactedKeySet_matchesSharedDiagnosticsContract`
  - `LinuxCrossPlatformRegressionTests::test_diagnosticsExport_redactedKeySet_matchesSharedDiagnosticsContract`
  - Shared-layer anchor: `CrossPlatformRegressionTests::test_diagnosticsRedactor_redactsKnownTokenKeys`.
- **History retention parity (`WindowsProviderHistoryStore` + `LinuxProviderHistoryStore` apply the same `ProviderHistoryRetention` window to a shared snapshot fixture)**:
  - `WindowsCrossPlatformRegressionTests::test_historyStore_appliesSharedRetentionFixture`
  - `LinuxCrossPlatformRegressionTests::test_historyStore_appliesSharedRetentionFixture`
  - Shared-layer anchor: `CrossPlatformRegressionTests::test_providerHistoryRetention_windowsAndDownsamplesOnSharedFixture`.
- **GitHub heatmap parity (`GitHubHeatmapResponseMapper` produces identical `GitHubHeatmapModels` output on each platform for a recorded fixture)**:
  - `WindowsCrossPlatformRegressionTests::test_githubHeatmapClient_producesIdenticalMappingForRecordedFixture`
  - `LinuxCrossPlatformRegressionTests::test_githubHeatmapClient_producesIdenticalMappingForRecordedFixture`
  - Shared-layer anchor: `CrossPlatformRegressionTests::test_githubHeatmapResponseMapper_producesIdenticalOutputForRecordedFixture`.

Notes on constraints honored by this step:

- No new production code was added; the suites consume only the public adapter surfaces shipped in 5.2 / 5.3 / 5.4 / 5.5.
- No new SwiftPM targets; suites live under the existing `PitwallSharedTests`, `PitwallWindowsTests`, and `PitwallLinuxTests` test targets.
- New test files contain no `import AppKit` / `import UserNotifications` / `import Security` / `import PitwallAppSupport`; Linux tests do not import `PitwallWindows` and vice versa. "Parity" between Windows and Linux is asserted by each platform suite comparing its own adapter output to the same hard-coded `Expected` constants, not by a cross-shell import.
- Fixture roots are injected as tmp directories; no test touches the user's real home directory, `%APPDATA%`, or XDG paths.
- **CI gap carried forward**: as with 5.3 / 5.4 / 5.5, no Windows / Linux CI host is configured yet. Because every adapter plus these regression suites are pure Foundation, macOS `swift test` runs `PitwallWindowsTests` and `PitwallLinuxTests` as a portability proxy. Step 5.7 inherits this gap.
- **Gap kept open for Step 5.7 / 5.8**: the regression suites do not exercise real Win32 / WinRT / `libsecret` / `libnotify` / `libayatana-appindicator` bindings. Those seams remain injected stubs until platform CI runners and production backend wiring land. Step 5.7 records whether macOS `swift test` alone satisfies the phase acceptance gate or whether the CI gap must be closed before Phase 5 ships.

## Deferred Decisions

Explicitly punted from Step 5.1. Each downstream step must resolve its own items before closing.

- **Exact shared-module split (Step 5.2)**: whether `PitwallAppSupport` contains enough portable logic to justify a `PitwallShared` target, or whether the portable pieces should simply move into `PitwallCore`. Step 5.2 performs that audit.
- **Tray toolkit choice per OS (Steps 5.3 / 5.4)**: Windows between raw Win32 `Shell_NotifyIcon` and a higher-level WinUI / WinAppSDK binding; Linux between `libappindicator` and `libayatana-appindicator`, plus the exact behavior when the desktop environment lacks indicator support.
- **Fallback storage documentation (Steps 5.3 / 5.4)**: the final user-visible copy for Linux-without-Secret-Service and Windows-with-restricted-Credential-Manager fallbacks. Both must make the degraded state obvious rather than silent.

## Non-Goals For Step 5.1

- No new source directories under `Sources/` (no `Sources/PitwallShared/`, `Sources/PitwallWindows/`, `Sources/PitwallLinux/`).
- No new test targets under `Tests/`.
- No edits to `Package.swift`.
- No edits to macOS shell files under `Sources/PitwallApp/`, `Sources/PitwallAppSupport/`, or `Sources/PitwallCore/`.
- No platform shell implementation. This document is a plan; Steps 5.2 through 5.5 do the work.
