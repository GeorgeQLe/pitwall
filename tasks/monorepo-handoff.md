# Pitwall / CalcLLM Monorepo Handoff

## Decision

Keep this repository as pure OSS Pitwall: local-first, no cloud sync, no team dashboards, and no CalcLLM product surface.

Future connected-mode work moves to a new GitHub monorepo that contains both:

- Pitwall Local: OSS/local-only app with no dependency on CalcLLM sync code.
- Pitwall powered by CalcLLM: connected edition with explicit opt-in sync, cloud dashboards, and team cost tracking.

## Recommended Monorepo Shape

```text
apps/
  pitwall-local/
  pitwall-calcllm/
packages/
  pitwall-core/
  pitwall-shared/
  pitwall-app-support/
  pitwall-macos-ui/
  calcllm-sync/
```

## Boundary Rules

- `apps/pitwall-local` must not import or link `packages/calcllm-sync`.
- Shared Pitwall packages should stay usable by the local-only app without remote services.
- CalcLLM auth, remote sync, account status, dashboard links, and team cost tracking belong only in the powered app/package.
- Connected-mode UI must clearly state what data is uploaded before a user connects.
- Disconnect must stop future sync and remove local CalcLLM tokens from secure storage.

## Initial Migration Steps

1. Create the new GitHub monorepo.
2. Import this repo's current clean OSS Pitwall code as the local app baseline.
3. Extract shared SwiftPM targets into packages without changing behavior.
4. Add `packages/calcllm-sync` for auth, token handling, account status, and snapshot sync.
5. Add `apps/pitwall-calcllm` that depends on shared Pitwall packages plus `calcllm-sync`.
6. Add tests that fail if `apps/pitwall-local` imports or links CalcLLM code.
7. Add connected-mode tests for request construction, token lifecycle, payload shape, disconnect, and redaction.

## Product Contract For Powered Edition

Before shipping the powered edition, document:

- Exact uploaded fields and excluded fields.
- User consent copy and first-connect flow.
- Server retention and deletion behavior.
- Token storage and refresh behavior.
- Team dashboard semantics.
- Branding distinction from OSS Pitwall Local.
