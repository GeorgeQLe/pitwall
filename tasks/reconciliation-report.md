# Dev Docs Reconciliation Report

> Generated: 2026-05-01 | Mode: fix | Scope: tasks

## Fixed

- [x] **tasks/todo.md:142** — Checked `Hotfix: Gemini passive configuration detection` parent checkbox (all 4 sub-steps were already checked, review section confirmed completion).
- [x] **tasks/roadmap.md** — Relabeled "Double Refresh Crash" and "Usage Calculation Accuracy Audit" from `Current Hotfix` to `Previous Hotfix` (both are fully completed).
- [x] **tasks/roadmap.md** — Added 4 missing hotfix entries: "Session-First Compact Menu Bar", "Rich Menu Bar Session Countdown for Claude", "Claude Session Countdown Fractional-Seconds Fix", "Periodic Auto-Refresh Timer".

## Deferred

- [ ] **tasks/roadmap.md** — Non-hotfix completed work has no roadmap entry: CalcLLM boundary cleanup, dead code cleanup, weekly cap feasibility indicator, code review fixes (from expert-review), F1 Quali theme fix. These are documented in `tasks/history.md` but not reflected in the roadmap. User judgment needed on whether these warrant roadmap sections or are fine as history-only records.
- [ ] **tasks/todo.md:9-11** — `## Priority Documentation Todo` contains 3 advisory items (`/pack`, `/spec-drift fix all`, `/reconcile-dev-docs`) that are tooling recommendations, not execution work. Consider moving to `tasks/record-todo.md` or removing now that reconciliation is complete.
- [ ] **specs/** — All 3 specs are stale (37+ source commits since last update). Recommended: `/spec-drift fix all`.

## Summary

| Area | Before | After |
|------|--------|-------|
| Roadmap/todo alignment | 1 error, 6 warnings | 0 errors, 3 deferred items |
| History coverage | OK | OK |
| Phase archives | OK (1-6a) | OK (1-6a) |
| Spec freshness | Stale (deferred) | Stale (deferred — scope was tasks only) |
| Manual tasks | OK | OK |
