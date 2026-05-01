# Spec Drift Report — 2026-05-01

## Resolved

- **E1** Pacing labels list incomplete — resolved by updating `specs/pitwall-macos-clean-room.md` to add `behind pace` and `not enough window` labels matching code enum.
- **E2** Codex session path pattern — resolved by updating spec from `sessions/YYYY/MM/DD/rollout-*.jsonl` to `sessions/**/*.jsonl` matching implementation.
- **E3** `make install` signing location — resolved by updating `specs/pitwall-macos-packaging.md` to reflect that signing happens in `scripts/build-app-bundle.sh`, not the install target.
- **E4** Diagnostic event summary names — resolved by updating spec from `packaging.firstLaunch.appSupportWritable`/`keychainRoundTrip` to `appSupportProbe`/`keychainProbe` matching code.
- **E5** `iguana_necktie` in response shape — resolved by annotating it as an example unknown key in the JSON sample, clarifying it is not a decoded section.

## Deferred

- **W1** Action label `switch` vs `switchProvider` — naming difference is due to Swift keyword avoidance; no spec update needed.
- **W2** Menu bar rotation default is 7s — within spec's stated 5–10s range; spec wording is acceptable as-is.

## Remaining

None.

## Archive

Pre-edit snapshots preserved at:
- `docs/history/archive/2026-05-01/spec-drift/pitwall-macos-clean-room.md`
- `docs/history/archive/2026-05-01/spec-drift/pitwall-macos-packaging.md`
