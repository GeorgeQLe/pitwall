# Lessons

- 2026-04-28: Do not equate provider settings-file presence with configured auth. For passive provider detection, require the actual auth artifact used by the provider before returning `.configured`; keep partial local evidence as diagnostics on a missing-configuration state.
- 2026-04-28: Do not equate `.configured` with menu-bar readiness. Live rotation needs displayable quota/pacing/reset/primary data; otherwise the menu bar can render useless fallback strings like "estimated configure."
