# Manual Todo - Pitwall

> Human-gated prerequisites that block future work. These are not code tasks — they require an account, payment, hardware, or an external service. Claude cannot execute them; the author must.
>
> When an item is resolved, move it to `## Completed` with a one-line resolution note and the date. If it unblocks a specific phase/step, record that on the completion line.
>
> Source of truth for human-gated blockers. Phase docs in `tasks/todo.md` and `tasks/roadmap.md` should link here rather than duplicate.

## Phase 6b — macOS Public Release prerequisites

Blocks: `/plan-phase 6b` and every Step 6b.* below it. Phase 6a ships without any of these.

- [ ] Enroll in the Apple Developer Program ($99/yr). _Blocks: Step 6b.1 (Sparkle + Developer ID signing), every subsequent notarization step._
- [ ] Request + install a Developer ID Application certificate from the Apple Developer portal into the author's login Keychain; export a `.p12` backup to the password manager. _Blocks: Step 6b.1._
- [ ] Generate an app-specific password at appleid.apple.com for `notarytool`, then run `xcrun notarytool store-credentials --apple-id … --team-id … pitwall-notary`. _Blocks: the first notarization submission._
- [ ] Generate a Sparkle 2.x EdDSA key pair; store the private key in the password manager only (never commit). Record the public key for `SUPublicEDKey` in `Info.plist`. _Blocks: the first appcast signature._
- [ ] Stand up a public hosting URL for `appcast.xml` (GitHub Pages on the Pitwall repo, or a raw file path). _Blocks: the first Sparkle update check._
- [ ] Create a self-hosted Homebrew tap repo `georgele/homebrew-pitwall`, OR submit the cask to upstream `homebrew-cask`. _Blocks: the first `brew install --cask` verification._

## Cross-platform parity prerequisites (post-v1 platform-limitation backlog)

Carried forward from Phase 5's documented CI gap (see `docs/cross-platform-architecture.md` §§5.3–5.8 and `tasks/roadmap.md` Phase 5 On Completion). Each item blocks the corresponding production-binding work in `tasks/todo.md` → "Post-v1 / Post-packaging Follow-ups".

- [ ] Provision a Windows CI runner (or a Windows host available to the author) that can run `swift build --triple x86_64-unknown-windows-msvc` + `swift test`. _Blocks: real Credential Manager / WinRT toast / Win32 tray / `FindFirstFileW` wiring and end-to-end Windows UX validation._
- [ ] Provision a Linux CI runner (or a Linux host available to the author) that can run `swift build` + `swift test`. _Blocks: real `libsecret` / `libnotify` / `libayatana-appindicator` / `stat(2)` wiring and end-to-end Linux UX validation._
- [ ] End-to-end tray + notification UX validation on a real Windows desktop session. _Blocks: flipping the Phase 5 "portability-proxy" disclaimer off for Windows._
- [ ] End-to-end tray + notification UX validation on a real Linux desktop session. _Blocks: flipping the Phase 5 "portability-proxy" disclaimer off for Linux._

## Completed

_(none yet)_
