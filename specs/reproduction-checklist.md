# Pitwall Reproduction Checklist

Use this checklist before implementing or reviewing a clean-room milestone.

## Clean-Room Boundary

- [ ] No Swift, Xcode, asset, screenshot, or test files copied from the prior ClaudeUsage fork lineage.
- [ ] Implementation is based on specs, public provider docs, and platform docs.
- [ ] New app structure, naming, and UI code are independently authored.
- [ ] MIT license remains accurate for all committed source files.

## macOS App Surface

- [ ] Native menu bar app with no Dock icon.
- [ ] Click-to-open popover.
- [ ] Settings window or sheet.
- [ ] First-run onboarding can be skipped.
- [ ] Launch-at-login preference.
- [ ] Manual refresh.
- [ ] Local notifications.
- [ ] Redacted diagnostics export.

## Claude

- [ ] Manual credential setup documents `sessionKey` and `lastActiveOrg`.
- [ ] App does not automate browser-cookie extraction.
- [ ] Session key stored in Keychain.
- [ ] Org id and account label stored outside Keychain.
- [ ] Usage request sends the `sessionKey` cookie and `anthropic-client-platform: web_claude_ai`.
- [ ] Parser handles known fields, unknown fields, and null sections.
- [ ] 401/403 enters expired-auth state.
- [ ] Set-Cookie session key rotation updates Keychain when present.
- [ ] Extra usage is displayed when returned.

## Pacing

- [ ] Weekly and session pacing are computed separately.
- [ ] Weekly pace ignores first 6 hours and last 1 hour.
- [ ] Session pace ignores first 15 minutes and last 5 minutes.
- [ ] Daily budget uses remaining weekly utilization and remaining days.
- [ ] Today's usage uses local-midnight snapshot baseline when available.
- [ ] Recommendations include push, conserve, switch, wait, and configure.
- [ ] UI avoids fake precision when confidence is low.

## Providers

- [ ] Codex passive detection uses local state without persisting prompts or tokens.
- [ ] Gemini passive detection uses local state without persisting prompts or tokens.
- [ ] Accuracy Mode wrappers do not capture stdout or prompt bodies.
- [ ] Provider Telemetry is off by default and opt-in per provider.
- [ ] Telemetry falls back to passive/wrapper state on failure.
- [ ] Confidence labels are visible and explained.

## Storage And Privacy

- [ ] Secrets are kept out of renderer/view state when possible.
- [ ] Saved secret inputs are write-only in UI.
- [ ] History stores derived usage snapshots only.
- [ ] Diagnostics redact cookies, tokens, auth headers, raw responses, prompts, and model responses.

## Tests

- [ ] Pacing thresholds and daily budget tests.
- [ ] Claude parsing fixtures.
- [ ] Backoff tests.
- [ ] History retention/downsampling tests.
- [ ] Provider confidence mapping tests.
- [ ] Diagnostics redaction tests.
