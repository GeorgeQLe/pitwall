# Clean-Room Implementation Note

Pitwall is a fresh implementation created to avoid inheriting unlicensed code from the prior ClaudeUsage fork lineage.

## Allowed Inputs

The implementation may use:

- Public provider documentation.
- Independently authored product requirements and specs in this repository.
- General platform documentation for Swift, SwiftUI, AppKit, Electron, TypeScript, and operating-system APIs.
- Independently researched market and product notes.

## Disallowed Inputs

Do not copy or mechanically translate:

- Swift, Xcode project, asset, or test files from `linuxlewis/claude-usage`.
- Swift, Xcode project, asset, or test files from `GeorgeQLe/claude-usage-review` that descend from the prior fork.
- Release artifacts, screenshots, bundled icons, or app binaries from the prior fork.
- File organization or implementation details that are only known from reading the prior Swift source, unless the same structure is a generic platform convention.

## Implementation Standard

Build from behavior and product requirements, not source inheritance. If a feature has to be reproduced, describe the required behavior in a spec first, then implement it fresh.

## Attribution

Pitwall may say it was inspired by prior usage-monitor experiments, but it should not claim affiliation with ClaudeUsage, Anthropic, OpenAI, Google, GitHub, or Cursor.
