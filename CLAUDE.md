# CLAUDE.md — Pitwall

> Project guide for Claude Code sessions. Keep this short and factual — the source of truth for product, workflow, and history lives in the files referenced below.

## What this project is

Pitwall is a clean-room, MIT-licensed Swift menu bar app that paces AI coding subscriptions (Claude, Codex, Gemini) across daily + weekly windows. The macOS app ships as `/Applications/Pitwall.app` via `make install`; Windows and Linux parity is in the `Pitwall{Windows,Linux}` targets behind shared `PitwallShared` / `PitwallCore` contracts. See `README.md` for product framing and `specs/pitwall-macos-clean-room.md` + `specs/pitwall-macos-packaging.md` for product requirements.

## Build / test

- `swift build` — primary build gate (macOS toolchain).
- `swift test` — full XCTest suite. **Current baseline: 212 / 212, zero regressions.** Any change must keep this green.
- `make build` — assembles `build/Pitwall.app` via `scripts/build-app-bundle.sh` (ad-hoc codesigned).
- `make install` / `make uninstall` — install/remove `/Applications/Pitwall.app`. `uninstall` preserves `~/Library/Application Support/Pitwall/` + Keychain items; treat both as destructive of the installed copy only.
- `bash scripts/smoke-install.sh` — packaging-artifact validator; run after any change to `scripts/build-app-bundle.sh`, `Makefile`, or `Sources/PitwallApp/Info.plist`.

## Module boundaries (enforced)

- `Sources/PitwallCore` — pure provider-agnostic models, pacing, Claude parsing, secret-store protocol, local-detector sanitization.
- `Sources/PitwallShared` — cross-platform shared behavior fixtures and contracts (no AppKit).
- `Sources/PitwallAppSupport` — macOS-host helpers that don't need AppKit (packaging version, login-item service, packaging probe).
- `Sources/PitwallApp` — macOS SwiftUI + AppKit shell.
- `Sources/PitwallWindows` / `Sources/PitwallLinux` — platform shells against `PitwallShared` contracts.

**Forbidden imports** — do not add `import AppKit`, `import UserNotifications`, or `import Security` to `PitwallShared`, `PitwallWindows`, or `PitwallLinux`. The pre-existing `import Security` in `Sources/PitwallCore/KeychainSecretStore.swift` is a grandfathered Phase 2 artifact.

## Clean-room rules

See `CLEAN_ROOM.md`. Short version: no copied Swift/Xcode/asset/test code from `linuxlewis/claude-usage` or forks. Specs are product requirements only. Fresh file names, structure, models, UI.

## Workflow docs (source of truth)

- `tasks/roadmap.md` — phase-level plan. Phases 1–6a are shipped; 6b is deferred.
- `tasks/todo.md` — priority task queue + current phase step detail.
- `tasks/manual-todo.md` — human-gated blockers (Apple Developer enrollment, Sparkle keys, Windows/Linux CI hosts). Non-code items only.
- `tasks/history.md` — append-only session log.
- `tasks/phases/phase-N.md` — archived phase snapshots on completion.
- `docs/cross-platform-architecture.md` — Phase 5 architecture decisions + platform-limitation disclaimers.

## Conventions

- **Ship-one-step contract.** Execute exactly one planned step per `/run` invocation; update `tasks/todo.md` + `tasks/history.md`; commit via `/commit-and-push-by-feature`; stop. The next step gets a fresh approval gate.
- **Refactor slots** (e.g. Step 5.8, Step 6a.11) may close as "no refactor required" when the surface is already tight — analogous to a docs-only close.
- **Phase archival** — when a phase's milestone acceptance criteria are ticked, snapshot the phase section into `tasks/phases/phase-N.md` and add a `Completed Phases` line in `tasks/todo.md`.
- **No network telemetry.** Diagnostics events route through `DiagnosticsRedactor` + `DiagnosticEventStore`; nothing is uploaded.
- **Secrets** — `KeychainSecretStore` on macOS; injected `InMemorySecretStore` in tests. Never serialize secrets into diagnostics, logs, or test fixtures.

## When in doubt

- Run `swift test` before claiming done.
- Never weaken a privacy fence (forbidden imports, redaction) without an explicit roadmap entry.
- Prefer adding a platform-limitation note in `docs/cross-platform-architecture.md` over silently bypassing a contract.
