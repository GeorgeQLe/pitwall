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

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity
- In Codex: use `update_plan` in Default mode and `request_user_input` only when already in Plan mode
- Do not assume a Claude-style clear-context-on-accept flow or related JSON setting exists

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff your behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/roadmap.md` (full plan) and `tasks/todo.md` (current phase) with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **Direct-To-Primary Git Flow**: Default to committing and pushing on the repository primary branch (`main` when present, otherwise `master`). Do not introduce or continue feature-branch workflows unless the user explicitly asks for them.
- **Always Ship Mutations**: If a task creates or modifies tracked files, finish by committing and pushing all intended changes before stopping unless the user explicitly says not to. Exception: direct Claude `/run` is execution-only and hands a dirty tracked tree to `/ship`. Claude clear-context sessions launched from `/ship` plan mode are ship-one-step sessions: implement the approved step, validate, update task docs/history, commit and push, deploy when an explicit manual deploy contract exists, write the next plan, ensure `.claude/settings.local.json` has `"showClearContextOnPlanAccept": true` and `"defaultMode": "acceptEdits"`, start the next approval UI with `EnterPlanMode` before `ExitPlanMode`, and stop before implementing the next step. If Claude refuses `EnterPlanMode` because an explicit user request is required, stop and ask the user to explicitly run `/plan <next step>`.
- **No GitHub Actions**: Do not create, modify, or suggest GitHub Actions workflows. This project does not use GitHub Actions for CI/CD.
