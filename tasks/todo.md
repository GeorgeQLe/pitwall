# Todo - Pitwall

> Current phase: none — Pitwall v1 roadmap complete (Phases 1–5 archived to `tasks/phases/`).
> Source roadmap: `tasks/roadmap.md`

## Priority Task Queue

- [ ] `/research-roadmap` - all five roadmap phases are checked off in `tasks/roadmap.md`; scan documentation health and maintain the priority documentation queue before post-v1 follow-ups are promoted into a new phase.

## Completed Phases

- [x] Phase 1 Foundation And Pacing Core completed and archived to `tasks/phases/phase-1.md`.
- [x] Phase 2 Provider Data Foundations completed and archived to `tasks/phases/phase-2.md`.
- [x] Phase 3 First Usable macOS Provider Parity completed and archived to `tasks/phases/phase-3.md`.
- [x] Phase 4 V1 Hardening, History, Diagnostics, Notifications, And GitHub Heatmap completed and archived to `tasks/phases/phase-4.md`.
- [x] Phase 5 Cross-Platform V1 Parity completed and archived to `tasks/phases/phase-5.md`.

## Pitwall v1 Status

All five planned roadmap phases are complete. The macOS menu bar app plus the Windows and Linux shells are shipped against `PitwallShared` / `PitwallCore` contracts with parity regression tests pinned to shared fixtures. 193 XCTest cases pass on macOS with zero regressions.

No new phase is scheduled — Phase 5 was the final v1 roadmap phase and no Phase 6 has been defined.

## Post-v1 Follow-ups (not scheduled)

These are documented platform limitations carried forward from the Phase 5 CI gap. They do not have an owning phase yet; promote into a new phase (or a focused hardening pass) when the team is ready to close them.

- Wire a real Windows CI runner and `swift build --triple x86_64-unknown-windows-msvc` + `swift test` on a Windows host.
- Wire a real Linux CI runner and `swift build` + `swift test` on a Linux host.
- Wire production Windows Credential Manager (`CredWriteW` / `CredReadW` / `CredDeleteW`) behind `WindowsCredentialManagerBackend`.
- Wire production `libsecret` / Secret Service behind `LinuxSecretServiceBackend`.
- Wire production WinRT `ToastNotificationManager` behind `WindowsToastDelivering`.
- Wire production `libnotify` / `org.freedesktop.Notifications` D-Bus behind `LinuxNotificationDelivering`.
- Wire production Win32 `Shell_NotifyIcon` tray glue on top of `WindowsTrayMenuViewModel`.
- Wire production `libayatana-appindicator` glue (plus the "no tray available" windowed popover fallback) on top of `LinuxTrayMenuViewModel`.
- Wire real filesystem probes for Codex/Gemini presence on Windows (`FindFirstFileW`-backed) and Linux (`stat(2)`-backed) behind the existing `*CodexFilesystemProbing` / `*GeminiFilesystemProbing` seams.
- End-to-end tray + notification UX validation in a real Windows or Linux desktop session.

## Next Step Recommendation

Run `/roadmap` to scan project state and recommend the next concrete work item (promote a follow-up into a new phase, start a hardening pass, or declare v1 done and move to post-v1 work).
