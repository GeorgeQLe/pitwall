# Pitwall

Pitwall is a clean-room, MIT-licensed desktop app for pacing AI coding subscriptions across Claude, Codex, Gemini, and future coding providers.

The product goal is simple: help power users know when to push, conserve, switch providers, or wait so they can maximize subscription value without burning through limits too early or falling into extra usage.

## Status

This repository is a fresh clean-room implementation. It intentionally does not copy Swift/Xcode source, assets, or release artifacts from `linuxlewis/claude-usage` or the previous `claude-usage-review` fork.

Phases 1–6a are shipped. Phase 6b (macOS public release) is in progress, blocked on manual prerequisites (Apple Developer enrollment, code signing, notarization).

- Native macOS menu bar app with real-time pacing across Claude, Codex, and Gemini.
- 277 tests passing across all modules.
- Local install via `make install`; signed release channel via `make release` (pending).
- Homebrew cask formula ready (pending tap publication).

### Cross-Platform

Windows and Linux platform shells exist in `Sources/PitwallWindows` and `Sources/PitwallLinux`, built on shared `PitwallCore` and `PitwallShared` contracts. They are not yet functional — blocked on CI hosts and platform-specific UI toolkits. Architecture decisions are documented in `docs/cross-platform-architecture.md`.

## Why Pitwall

Most quota tools tell you how close you are to a limit. Pitwall focuses on pacing:

- How much can I safely use today without spending the rest of the week at the limit?
- Am I under-using my subscription and leaving value on the table?
- Should I use Claude, Codex, or Gemini for the next task?
- Is this reading exact, provider-supplied, estimated, or only locally observed?
- Will continuing at this burn rate push me into extra usage or pay-as-you-go spend?

## Clean-Room Rules

See `CLEAN_ROOM.md` before implementing. The short version:

- Do not copy upstream Swift, Xcode, asset, or test code.
- Use specs as product requirements only.
- Implement fresh file names, structure, models, and UI code unless they are generic platform conventions.
- Keep attribution factual without implying affiliation.

Future app targets should be implemented from the repository specs, public provider documentation, and public Apple platform documentation. Do not use prior ClaudeUsage Swift source, Xcode project files, assets, screenshots, release artifacts, or descended fork implementation details as development inputs.

## Development

Pitwall builds as a Swift package (Swift 5.9, macOS 13.0+) with six modules:

- `PitwallCore` — provider-agnostic pacing models, calculations, Claude parsing, secret-store protocol.
- `PitwallShared` — cross-platform shared behavior fixtures and contracts (no AppKit).
- `PitwallAppSupport` — macOS-host helpers (packaging version, login-item service).
- `PitwallApp` — macOS SwiftUI + AppKit menu bar shell (executable).
- `PitwallWindows` / `PitwallLinux` — platform shells against `PitwallShared` contracts.

```sh
swift build        # Build all modules
swift test         # Run full test suite (277 tests)
make build         # Assemble build/Pitwall.app (ad-hoc codesigned)
make install       # Install to /Applications/Pitwall.app
make uninstall     # Remove app (preserves user data + Keychain)
```

## Installation

From source:

```sh
make install
```

After the first public release, via Homebrew:

```sh
brew tap georgele/pitwall
brew install --cask pitwall
```

Signed DMG releases on GitHub Releases are planned once Apple Developer enrollment and notarization are complete.

## Claude Credential Setup

Pitwall should use an explicit user-driven credential flow. It must not automatically extract cookies from the browser.

For Claude support, the user will:

1. Open `https://claude.ai` while signed in.
2. Open browser developer tools.
3. Go to the Application or Storage tab.
4. Open Cookies for `https://claude.ai`.
5. Copy the `sessionKey` cookie value.
6. Copy the `lastActiveOrg` cookie value as the organization id.
7. Paste both into Pitwall settings.

The session key is sensitive and must be stored in the macOS Keychain. The UI should show only a saved/configured state after the credential is saved.

## Website

Open `docs/index.html` locally or configure GitHub Pages to serve from the `docs/` folder.

## License

MIT. See `LICENSE`.

Pitwall is independent and is not affiliated with Anthropic, OpenAI, Google, GitHub, Cursor, or the ClaudeUsage project.
