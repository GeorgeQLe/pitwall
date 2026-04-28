# Lessons

- 2026-04-28: Do not use neutral theme markers for actual-vs-target usage comparisons. When a menu bar segment has both actual usage and expected pace, grade it through the shared pace-status mapping; reserve target icons for target-only displays.
- 2026-04-28: Do not equate provider settings-file presence with configured auth. For passive provider detection, require the actual auth artifact used by the provider before returning `.configured`; keep partial local evidence as diagnostics on a missing-configuration state.
- 2026-04-28: Do not equate `.configured` with menu-bar readiness. Live rotation needs displayable quota/pacing/reset/primary data; otherwise the menu bar can render useless fallback strings like "estimated configure."
