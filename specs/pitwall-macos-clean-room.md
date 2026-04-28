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
- MenuBarExtra or equivalent native status-item surface
- Keychain for secrets
- UserDefaults or app-support storage for non-secret settings and history
- URLSession for network requests
- Local notifications for reset/auth/degraded-provider events

## App Capabilities

The macOS app should reproduce the full product behavior from requirements, not source code:

- persistent menu bar presence
- click-to-open popover
- settings window or sheet
- first-run provider setup
- multi-account Claude support
- provider cards for Claude, Codex, and Gemini
- optional GitHub contribution heatmap
- history sparklines
- launch-at-login toggle
- manual refresh
- local notifications
- redacted diagnostics export

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
- `actions`

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
- estimated extra-usage exposure when a provider exposes paid overflow usage

Pacing labels:

- underusing
- on pace
- ahead of pace
- warning
- critical
- capped

### Pacing Rules

Use separate session and weekly pacing calculations.

Weekly pacing:

- Source: Claude seven-day utilization when available.
- Window: provider-supplied reset timestamp when available.
- Ignore weekly pace in the first 6 hours of the window and the last 1 hour before reset.
- Compute elapsed percentage as `elapsedWindow / totalWindow`.
- Compute pace ratio as `actualUtilization / expectedUtilizationAtThisPoint`.
- Treat 100% or higher utilization as capped.

Session pacing:

- Source: Claude five-hour utilization when available.
- Window: provider-supplied reset timestamp when available.
- Ignore session pace in the first 15 minutes of the window and the last 5 minutes before reset.
- Compute pace ratio using the same shape as weekly pace.

Initial threshold targets:

- `underusing`: ratio below `0.50`
- `behind pace`: ratio from `0.50` to below `0.85`
- `on pace`: ratio from `0.85` through `1.15`
- `ahead of pace`: ratio above `1.15` through `1.50`
- `warning`: ratio above `1.50` through `2.00`
- `critical`: ratio above `2.00` or projected cap before the next meaningful work block
- `capped`: utilization greater than or equal to `100`

Daily budget:

- Compute remaining utilization as `max(0, 100 - weeklyUtilization)`.
- Compute days remaining from the weekly reset timestamp with fractional days allowed.
- Daily budget is `remainingUtilization / max(daysRemaining, 1/24)`.
- Today's usage is the delta between current weekly utilization and the closest retained snapshot before local midnight, falling back to the earliest same-day snapshot.
- If no baseline exists, show "today unknown" and avoid pretending the delta is exact.

Action guidance:

- `push`: underusing or on pace with meaningful remaining headroom.
- `conserve`: ahead of pace or warning.
- `switch`: current provider is ahead/warning/critical and another provider has better confidence-adjusted headroom.
- `wait`: reset is soon enough that waiting is preferable to extra usage or risky work.
- `configure`: provider lacks enough information to make a recommendation.

## Providers

### Claude

Use a user-provided session key and organization id to call the Claude usage endpoint. Treat this as unofficial and subject to breakage.

Endpoint:

- Method: `GET`
- URL: `https://claude.ai/api/organizations/{orgId}/usage`
- Cookie: `sessionKey={sessionKey}`
- Header: `anthropic-client-platform: web_claude_ai`

Expected response shape:

```json
{
  "five_hour": { "utilization": 17.0, "resets_at": "2026-02-08T18:59:59Z" },
  "seven_day": { "utilization": 11.0, "resets_at": "2026-02-14T16:59:59Z" },
  "seven_day_sonnet": { "utilization": 0.0, "resets_at": null },
  "seven_day_opus": { "utilization": 5.0, "resets_at": "2026-02-14T16:59:59Z" },
  "seven_day_oauth_apps": null,
  "seven_day_cowork": null,
  "iguana_necktie": { "utilization": 0.0, "resets_at": null },
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 100.0,
    "used_credits": 12.5,
    "utilization": 12.5
  }
}
```

Parsing requirements:

- Unknown usage keys should not crash parsing.
- Null usage sections should be ignored in the usage-list UI.
- Known sections should use friendly labels:
  - `five_hour`: Session
  - `seven_day`: Weekly
  - `seven_day_sonnet`: Sonnet
  - `seven_day_opus`: Opus
  - `seven_day_oauth_apps`: OAuth apps
  - `seven_day_cowork`: Cowork
  - `extra_usage`: Extra usage
- Utilization is a percentage where `100` means the displayed limit is exhausted.
- Reset timestamps are UTC ISO-8601 and should display in local time.

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

Auth errors:

- Treat `401` and `403` as expired or invalid auth.
- Keep the account metadata but mark the provider expired.
- Surface an action to reopen settings and replace credentials.

Network errors:

- Keep the last successful snapshot visible with stale labeling.
- Show a concise error state in the popover.
- Use exponential backoff described in `Polling`.

### Codex

Use passive local detection by default and optional provider telemetry if supported by existing CLI auth.

Required behavior:

- Detect likely Codex installation and local activity.
- Avoid reading or persisting raw prompt content.
- Support plan/profile configuration when exact usage is unavailable.
- Use confidence labels instead of fake exact percentages.
- Surface rate-limit or lockout signals when visible.

Passive sources:

- `CODEX_HOME` when set, otherwise `~/.codex`.
- `config.toml` for install/config detection.
- `auth.json` for auth presence only; do not serialize token contents.
- `history.jsonl` with incremental byte-offset bookmarks.
- `sessions/YYYY/MM/DD/rollout-*.jsonl` recursively where present.
- Local logs for rate-limit, usage-limit, lockout, or reset text where present.

Accuracy Mode:

- Optional wrapper command generated by the app.
- Captures invocation start/end timestamps.
- Captures command mode and model only when safely observable.
- Captures exit status.
- Scans stderr in memory for rate-limit, usage-limit, lockout, and reset hints.
- Does not capture stdout.
- Does not persist prompt bodies.

Telemetry mode:

- Opt-in and off by default.
- Reuses the supported Codex CLI auth paths, including app-orchestrated device auth for ChatGPT sign-in.
- Preferred implementation: launch `codex app-server --listen stdio://`, initialize the JSON-RPC app-server protocol, then call `account/rateLimits/read`.
- The CLI app-server performs the ChatGPT-authenticated usage request internally and currently reaches `https://chatgpt.com/backend-api/wham/usage`; Pitwall must treat that URL as a CLI implementation detail and should not read `auth.json` token values or call the endpoint directly.
- API-key login remains supported for Codex auth setup, but ChatGPT plan quota telemetry should be skipped unless the CLI exposes a rate-limit response for that auth mode.
- Parse provider-supplied fields when present: limit id, limit name, window label, used percent, reset time, window duration, credits, balance, unlimited flag, plan type.
- If telemetry fails or response shape changes, mark telemetry degraded and fall back to passive or wrapper state.

Confidence rules:

- `exact` or `providerSupplied`: successful telemetry response with parseable current quota snapshots.
- `highConfidence`: repeated observed limit/reset patterns plus configured plan/profile.
- `estimated`: plan/profile plus passive activity or wrapper events.
- `observedOnly`: install/auth/activity evidence without enough quota context.

### Gemini

Use passive local detection by default and optional Code Assist quota telemetry if supported by existing CLI auth.

Required behavior:

- Detect likely Gemini CLI installation and local activity.
- Avoid reading or persisting raw prompt content.
- Support auth-mode/profile configuration.
- Show quota buckets without forcing them into Claude's percentage model unless the data supports it.

Passive sources:

- `GEMINI_HOME` when supported/configured, otherwise `~/.gemini`.
- `settings.json` for install/config detection.
- `oauth_creds.json` for auth presence only.
- `tmp/**/chats/session-*.json` for local request/timestamp/token/model data where present.

Command summary:

- The app may guide users to Gemini CLI `/stats` where available.
- Treat command-derived summaries as higher confidence than raw local file observation but still label confidence according to data quality.

Telemetry mode:

- Opt-in and off by default.
- Reuses existing Gemini or Google auth only; no new Google login flow.
- Code Assist quota endpoint: `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`
- Request body shape: `{ "project": "<code-assist-project-id>" }`
- Parse quota buckets when present: model id, token type, remaining amount, remaining fraction, reset time.
- If credentials are encrypted or cannot be used safely, mark telemetry unavailable and keep passive monitoring active.

Confidence rules:

- `exact` or `providerSupplied`: successful provider quota response with parseable current buckets.
- `highConfidence`: authenticated mode, configured profile, and reliable local or `/stats` data.
- `estimated`: authenticated mode with local request data but incomplete quota context.
- `observedOnly`: local activity without plan/auth confidence.

## Accounts And Storage

### Account Model

Claude accounts:

- stable id
- display label or email
- organization id
- configured status
- last successful refresh timestamp
- provider-specific error state

Provider profiles:

- provider id
- enabled flag
- account label
- plan/profile
- auth mode when relevant
- telemetry enabled flag
- accuracy mode enabled flag
- last confidence explanation

### Secret Storage

Store in Keychain:

- Claude session keys.
- GitHub personal access token if GitHub heatmap is enabled.
- Any future provider token that Pitwall explicitly owns.

Do not store in app-support analytics/history:

- raw Claude session key
- provider auth tokens
- raw provider endpoint responses by default
- prompt text
- model responses
- source code content

### Non-Secret Storage

Store in app support or UserDefaults:

- account labels and ids
- Claude org ids
- provider enablement
- plan/profile selections
- telemetry and accuracy-mode settings
- history snapshots
- diagnostic events after redaction
- wrapper event metadata
- filesystem bookmarks or byte offsets for incremental reads

## Polling And Refresh

Claude:

- Default polling interval: 5 minutes.
- Manual refresh is always available.
- Schedule an auto-refresh at a provider reset timestamp when known.
- Live countdown text updates every second from local state; it must not trigger network polling every second.

Network backoff:

- On consecutive network failures, use `min(300 * 2^n, 3600)` seconds where `n` is the consecutive failure count.
- Progression after first failures: 600s, 1200s, 2400s, 3600s cap.
- Successful refresh resets the failure count.
- Auth errors reset network backoff and enter expired-auth state.

Telemetry:

- Default telemetry refresh: 5 minutes while app is active.
- Manual refresh bypasses backoff for that attempt.
- After 3 consecutive telemetry failures, mark telemetry degraded.
- Telemetry backoff is capped at 30 minutes.

Passive local providers:

- Default passive scan cadence: 15 seconds.
- Filesystem event debounce: 1 second.
- Wrapper events update state immediately.

## Menu Bar

The menu bar item should show compact pacing status, not just raw usage.

Example states:

- `Claude 82% - 41m - conserve`
- `Codex high - 5h est`
- `Gemini 412/1000 - safe`
- `Mixed - switch to Gemini`

The user can choose a pinned provider or allow provider rotation.

Behavior:

- Rotate enabled providers every 5 to 10 seconds by default.
- Preserve manual override until the user changes provider, clears override, or pins a provider.
- Skip degraded providers during automatic rotation when at least one non-degraded provider exists.
- Context menu actions: refresh now, open settings, pause rotation, select provider, quit.
- Support user preference for reset-time display versus live countdown.
- If a provider is missing configuration, show that clearly rather than a fake zero.

## Popover

The popover should show:

- current recommended action: push, conserve, switch, wait, or configure
- provider cards for enabled providers
- confidence labels and explanations
- daily budget and days remaining
- reset countdowns
- recent history sparkline or compact trend
- settings, refresh, and add-account controls

Claude usage rows:

- name
- circular progress indicator
- percentage
- horizontal bar
- reset time or countdown
- stale/error indicator when relevant

Provider cards:

- provider name and status
- auth mode or plan/profile
- confidence label
- primary headroom metric
- secondary reset/rate/cooldown metric
- last updated time
- stale/degraded/missing badge
- confidence explanation in plain language
- quick action to configure, refresh, enable telemetry, or open Accuracy Mode setup

Optional sections:

- collapsible history with session and weekly sparklines
- GitHub contribution heatmap for the last 12 weeks

## Settings

Settings should include:

- account management: add, rename, switch, delete
- provider enablement
- Claude account credentials
- account labels
- provider plan/profile details
- test connection
- time display preference: reset time or countdown
- pace display preference
- weekly color mode: pace-aware or raw percentage
- polling interval
- launch at login
- optional GitHub username and token
- privacy and telemetry mode controls
- Accuracy Mode setup and verification
- diagnostics export with redaction

Secrets must never be rendered back into the UI after saving.

## Onboarding

First launch should guide the user through:

1. Choose providers to monitor.
2. Configure Claude account if desired.
3. Auto-detect Codex and Gemini installations.
4. Confirm Codex plan/profile and Gemini auth mode/profile.
5. Choose tray rotation behavior.
6. Choose whether to enable telemetry or Accuracy Mode.

Onboarding can be skipped. Skipped or missing providers should remain visible as configurable states, not hard failures.

## Notifications

Local notification events:

- Claude session reset.
- Claude auth expires.
- Provider telemetry becomes degraded after repeated failures.
- Optional warning when a provider crosses user-configured pacing/rate thresholds.

Notifications must be user configurable.

## History

Persist per-account usage snapshots:

- Keep all snapshots for the last 24 hours.
- Downsample snapshots from 24 hours to 7 days to one per hour.
- When downsampling a bucket, retain the highest session utilization and latest weekly utilization in that hour.
- Drop snapshots older than 7 days unless a future retention setting is added.

History snapshots should include:

- account id
- timestamp
- provider id
- confidence
- session utilization when available
- weekly utilization when available
- reset timestamps when available
- headline values needed for sparklines and daily-budget calculations.

## GitHub Heatmap

Optional GitHub contribution heatmap:

- User supplies username and personal access token.
- Token is stored in Keychain.
- Fetch through GitHub GraphQL with variables, not string interpolation.
- Display last 12 weeks.
- Refresh no more often than hourly unless manually requested.
- Treat `401` and `403` as invalid or expired token.

## Diagnostics

Diagnostics export should include:

- app version and build metadata
- enabled provider ids
- provider status and confidence
- redacted error states
- last successful refresh timestamps
- storage health
- recent diagnostic event summaries

Diagnostics must redact:

- cookies
- tokens
- account ids where not needed
- auth headers
- raw endpoint responses unless explicitly redacted
- prompt and model-response content

## Verification

Initial implementation should include tests for:

- pacing calculations
- provider confidence mapping
- Claude usage response parsing with fixtures
- Keychain abstraction through injected test storage
- settings persistence
- no raw prompt persistence in provider parsers
- network backoff behavior
- history retention/downsampling
- telemetry degradation and fallback states
- diagnostics redaction

## Open Questions

- Confirm whether the Claude usage endpoint still returns every listed field at implementation time.
- Confirm current Codex and Gemini telemetry surfaces before shipping telemetry mode.
- Decide whether the optional GitHub heatmap remains part of v1 or moves behind a later milestone.
- Decide whether Windows/Linux Electron parity belongs in this repository before the macOS app reaches parity.
