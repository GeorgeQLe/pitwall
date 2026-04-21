# Pitwall macOS Clean-Room Spec

## Summary

Build a native macOS menu bar app that helps AI coding power users pace subscription-backed usage across Claude, Codex, Gemini, and future providers.

The first release should answer:

- How much can I safely use right now?
- Am I ahead of or behind sustainable pace?
- Which provider should I use next?
- When do the relevant windows reset?
- Which readings are exact, provider-supplied, estimated, or observed locally?

## Non-Goals

- Do not copy the prior ClaudeUsage Swift implementation.
- Do not promise exact quota for providers without a defensible source.
- Do not collect prompt text or source code content.
- Do not add cloud sync, analytics upload, or team dashboards in v1.
- Do not automate browser-cookie extraction.

## Platform

- macOS 13+
- Swift and SwiftUI
- Menu bar app with no Dock icon
- Keychain for secrets
- UserDefaults or app-support storage for non-secret settings and history
- URLSession for network requests

## Product Model

### Provider State

Each provider exposes a normalized state:

- `providerId`
- `displayName`
- `status`: configured, missingConfiguration, stale, degraded, expired
- `confidence`: exact, providerSupplied, highConfidence, estimated, observedOnly
- `headline`
- `primaryValue`
- `secondaryValue`
- `resetAt`
- `lastUpdatedAt`
- `pacingState`
- `confidenceExplanation`

Provider-specific payloads remain separate so the UI does not force all providers into the same quota shape.

### Pacing State

Pitwall should compute:

- weekly utilization
- remaining window duration
- daily budget to stay below the cap
- usage since local midnight
- current burn rate
- projected cap time at current burn rate
- under-use signal when the user can safely use more
- over-use signal when the user risks multi-day lockout or extra usage

Pacing labels:

- underusing
- on pace
- ahead of pace
- warning
- critical
- capped

## Providers

### Claude

Use a user-provided session key and organization id to call the Claude usage endpoint. Treat this as unofficial and subject to breakage.

Pitwall must not automatically extract cookies from the user's browser. Claude credentials are provided by the user through a guided setup screen.

Setup instructions shown in-app:

1. Open `https://claude.ai` in the browser where the user is signed in.
2. Open browser developer tools.
3. Go to the Application or Storage tab.
4. Open Cookies for `https://claude.ai`.
5. Copy the `sessionKey` cookie value.
6. Copy the `lastActiveOrg` cookie value as the organization id.
7. Paste both values into Pitwall settings.

The app should explain that these values are sensitive account credentials and should only be stored locally.

Required behavior:

- Store session key in Keychain.
- Store org id and account label outside Keychain.
- Keep credential inputs write-only after saving; show saved/configured state instead of rendering the session key back into the UI.
- Provide a "Test connection" action that validates the session key and org id without waiting for the polling interval.
- Refresh every 5 minutes by default.
- Handle 401/403 as expired auth.
- Handle session key rotation if a response provides a replacement cookie.
- Show exact confidence when fresh usage data is available.
- Show session, weekly, model-specific, and extra-usage fields when present.

### Codex

Use passive local detection by default and optional provider telemetry if supported by existing CLI auth.

Required behavior:

- Detect likely Codex installation and local activity.
- Avoid reading or persisting raw prompt content.
- Support plan/profile configuration when exact usage is unavailable.
- Use confidence labels instead of fake exact percentages.
- Surface rate-limit or lockout signals when visible.

### Gemini

Use passive local detection by default and optional Code Assist quota telemetry if supported by existing CLI auth.

Required behavior:

- Detect likely Gemini CLI installation and local activity.
- Avoid reading or persisting raw prompt content.
- Support auth-mode/profile configuration.
- Show quota buckets without forcing them into Claude's percentage model unless the data supports it.

## Menu Bar

The menu bar item should show compact pacing status, not just raw usage.

Example states:

- `Claude 82% - 41m - conserve`
- `Codex high - 5h est`
- `Gemini 412/1000 - safe`
- `Mixed - switch to Gemini`

The user can choose a pinned provider or allow provider rotation.

## Popover

The popover should show:

- current recommended action: push, conserve, switch, wait, or configure
- provider cards for enabled providers
- confidence labels and explanations
- daily budget and days remaining
- reset countdowns
- recent history sparkline or compact trend
- settings, refresh, and add-account controls

## Settings

Settings should include:

- provider enablement
- Claude account credentials
- account labels
- provider plan/profile details
- polling interval
- launch at login
- privacy and telemetry mode controls
- diagnostics export with redaction

Secrets must never be rendered back into the UI after saving.

## Verification

Initial implementation should include tests for:

- pacing calculations
- provider confidence mapping
- Claude usage response parsing with fixtures
- Keychain abstraction through injected test storage
- settings persistence
- no raw prompt persistence in provider parsers
