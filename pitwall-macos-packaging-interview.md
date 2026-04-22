# Pitwall macOS Packaging — Interview Log

Date: 2026-04-22
Topic: packaging and distribution for the Pitwall macOS menu bar app
Driver: user wants to replace the legacy ClaudeUsage menu bar with Pitwall; Phase 5 (cross-platform parity) just shipped with the macOS app functionally complete but not packaged/signed/notarized.
Project designation: `.agents/project.json` absent; inferred `business-app` default. No `research/icp.md` present.

## Turn 1 — Distribution scope, update channel, release automation

**Questions asked**:

1. *Distribution scope*: Who is Pitwall being packaged for in the first release — and does that require a Developer ID / notarization?
   - Personal use only (ad-hoc sign).
   - Public download, signed + notarized (Recommended).
   - Public via Homebrew cask + signed/notarized.
   - Mac App Store (not recommended — sandbox breaks Pitwall's Keychain + filesystem + networking patterns).
2. *Update channel*: How should the app auto-update after first install?
   - Manual re-download for v1.0, Sparkle later.
   - Sparkle 2 with EdDSA-signed appcast (Recommended).
   - No auto-update, ever.
3. *Release automation*: How should the release pipeline be automated?
   - Local `make release` script (Recommended).
   - GitHub Actions macOS runner.
   - Xcode archive + manual Notary UI.

**Answers**:

1. User replied with a clarifying question instead of selecting: *"how were we able to run the claudeusage menu bar without doing all of this stuff?"*
2. Sparkle 2 with EdDSA-signed appcast.
3. Local `make release` script.

**Response to clarifying question**: explained the three tiers — (a) build from source = no quarantine xattr, no Developer ID needed (how the old ClaudeUsage actually got used), (b) download someone else's zip = Gatekeeper requires Developer ID + notarization, (c) Mac App Store = different sandbox world. Flagged that the user's Sparkle + `make release` picks implied option (b), so re-asked distribution scope with that context.

## Turn 2 — Distribution scope (retry), app icon, versioning + login-item

**Questions asked**:

1. *Distribution scope retry*:
   - Just you — drop Sparkle + signing, just build locally.
   - Public, signed, notarized, with Sparkle (Recommended — matched earlier picks).
   - Hybrid: personal path now, signed path later.
2. *App icon*:
   - Need to create one (Recommended for v1).
   - I have an icon ready.
   - Ship with no app icon.
3. *Version + autostart*:
   - Semver + `SMAppService` login-item (Recommended).
   - Build-number only + no login-item.
   - Semver only, no login-item.

**Answers**:

1. User selected "Public, signed, notarized, with Sparkle" but followed up mid-turn with *"like can we do option 1 with option 2, when we're ready to release it wide?"* — interpreted as wanting the Hybrid split.
2. Need to create one (SF Symbol-based placeholder).
3. Semver + `SMAppService` login-item.

**Response to follow-up**: confirmed that option 3 (Hybrid) is the sensible path. Proposed splitting into Phase 6a (personal local install, ship now, $0) and Phase 6b (public signed release, later, $99/yr). Phase 6a's `make install` becomes the first steps of Phase 6b's `make release`, so no rework.

## Turn 3 — Phase split confirmation, 6a open questions, 6b distribution channel

**Questions asked**:

1. *Phase split*:
   - Yes, split into 6a + 6b (Recommended).
   - Single Phase 6 covering both.
   - Only Phase 6a; defer 6b as an unscoped follow-up.
2. *Phase 6a open questions* (multi-select): uninstall story, menu bar icon asset format, first-launch diagnostics, migration from old ClaudeUsage data.
3. *Phase 6b distribution channel*:
   - GitHub Releases DMG only (Recommended).
   - GitHub Releases + Homebrew cask.
   - Decide later during 6b planning.

**Answers**:

1. Yes, split into 6a + 6b.
2. All four flagged as needing spec decisions.
3. GitHub Releases + Homebrew cask.

## Turn 4 — Drill-down on the four 6a open questions

**Questions asked**:

1. *Uninstall*:
   - Remove app + login-item; keep data (Recommended).
   - Remove app + login-item + data + Keychain.
   - Offer both `make uninstall` and `make purge`.
2. *Icon asset*:
   - SF Symbol (Recommended, clean-room-safe, zero binary assets).
   - Template PNG `.imageset`.
   - SF Symbol now, reserve custom icon slot for 6b.
3. *Health check*:
   - Minimal: App Support + Keychain probe, logged to DiagnosticEventStore (Recommended).
   - Add a local crash log writer on top.
   - No first-launch check.
4. *Migration from old ClaudeUsage*:
   - No migration — user re-enters session key (Recommended, preserves clean-room boundary).
   - Opt-in one-shot import from ClaudeUsage Keychain.
   - Detect old app's presence, show a migration hint only.

**Answers**:

1. Remove app + login-item; keep data.
2. SF Symbol.
3. Minimal App Support + Keychain probe.
4. No migration.

All four matched the Recommended option.

## Turn 5 — Coverage check

**Question**: Does this cover everything, or should we revisit an area?

**Answer**: Yes, write the spec.

## Deviation Summary

The spec deviates from the user's initial intent in two meaningful ways, both initiated by the user mid-interview:

1. **Phase split (user-initiated)**. The first pass implied a single Phase 6 releasing publicly with Sparkle immediately. After the user asked how ClaudeUsage ran without signing, the shape shifted to a Phase 6a (personal install, $0, ship now) + Phase 6b (public signed release, later, $99/yr) split. Phase 6a unblocks the "swap my menu bar" use case immediately; Phase 6b is written but deferred until the "share with others" decision is actually made. No rework between the two phases.
2. **Mac App Store ruled out**. Presented as an option; user did not select it, but the spec formalizes the rejection in the Non-Goals section because the sandbox entitlements would break Keychain, filesystem probing of `~/.codex` / `~/.gemini`, and the Claude cookie-bearing network requests. Recording this explicitly so future phases don't re-litigate it.

Minor deviations from Recommended defaults: none. All of the user's selections matched the Recommended option for every question except the initial distribution-scope retry (which pivoted to Hybrid based on a follow-up message rather than the on-screen pick).

## Deliverables

- `specs/pitwall-macos-packaging.md` — completed specification covering Phase 6a (personal local install) and Phase 6b (public signed release).
- `pitwall-macos-packaging-interview.md` — this file.

## Clean-Room Boundary Notes

- Phase 6a explicitly does not read any ClaudeUsage-authored Keychain item, config file, or stored setting. Users re-enter credentials in the existing Phase 3 onboarding flow. This preserves the clean-room boundary recorded in `CLEAN_ROOM.md` and `specs/pitwall-macos-clean-room.md`.
- Phase 6b's Developer ID certificate, notarization credentials, Sparkle EdDSA key, and appcast infrastructure are project infrastructure (not ClaudeUsage-derived artifacts). No clean-room boundary change is triggered by 6b; the `CLEAN_ROOM.md` update mentioned in the spec is a note-level amendment, not a policy shift.
