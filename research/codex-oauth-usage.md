# Codex OAuth Usage Research

Date: 2026-04-27

## Finding

Pitwall can get Claude-like Codex usage without reading OAuth tokens by using the Codex CLI app-server protocol:

1. Launch `codex app-server --listen stdio://`.
2. Send JSON-RPC `initialize` with `experimentalApi: true`.
3. Send JSON-RPC `account/rateLimits/read`.
4. Parse the returned `GetAccountRateLimitsResponse`.

The response shape contains the quota fields Pitwall needs:

- `rateLimits.limitId`
- `rateLimits.limitName`
- `rateLimits.primary.usedPercent`
- `rateLimits.primary.windowDurationMins`
- `rateLimits.primary.resetsAt`
- `rateLimits.secondary.usedPercent`
- `rateLimits.secondary.windowDurationMins`
- `rateLimits.secondary.resetsAt`
- `rateLimits.credits.hasCredits`
- `rateLimits.credits.unlimited`
- `rateLimits.credits.balance`
- `rateLimits.planType`
- `rateLimits.rateLimitReachedType`
- `rateLimitsByLimitId`

## Evidence

- Local Codex CLI version checked: `codex-cli 0.125.0`.
- Local `codex login status` reported ChatGPT auth.
- The installed Codex native binary includes app-server protocol strings for `account/rateLimits/read`, `GetAccountRateLimitsResponse`, `RateLimitSnapshot`, `RateLimitWindow`, and usage endpoints `/api/codex/usage` / `/wham/usage`.
- `codex app-server generate-ts --out /tmp/codex-appserver-schema` produced generated TypeScript bindings confirming the request method and response schema.
- A live app-server probe outside the sandbox returned a `codex` quota bucket plus a model-specific bucket, with five-hour and weekly windows.

## External Notes

- OpenAI Help documents that Codex usage limits depend on the user's ChatGPT plan and reset windows vary by plan/task complexity: <https://help.openai.com/en/articles/11369540-codex-in-chatgpt>
- OpenAI Help also says Codex usage in local environments is not available through the Compliance API, so that route does not solve Pitwall's local menu-bar use case: <https://help.openai.com/en/articles/11369540-codex-in-chatgpt>

## Decision

Use the Codex CLI app-server as the integration boundary. Pitwall should not read access tokens, refresh tokens, ID tokens, or browser cookies. If the app-server request fails because the CLI is unavailable, auth is API-key-only, network is unavailable, or the schema changes, Pitwall should keep the current passive Codex state and mark telemetry unavailable.
