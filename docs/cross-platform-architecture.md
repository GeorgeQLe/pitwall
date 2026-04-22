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
