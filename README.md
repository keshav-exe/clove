# Clove

Native Mac app that finds every agent skill on your machine and lets you copy or drop them into prompts.

**Free and open source.** MIT license. No account. No paywall.

[Download for Mac](https://github.com/keshav-exe/clove/releases/latest) · [Website](https://www.kshv.me/clove)

<img src="https://www.kshv.me/clove/product-preview.png" alt="Clove quick access panel searching agent skills" width="720" />

## What it does

Skills live in `~/.cursor`, `~/.claude`, plugins, and project folders. Referencing them in a prompt means remembering a slash command or digging through Finder.

Clove scans every `SKILL.md` on your Mac and puts them in one searchable library.

- Search names, descriptions, and tags across Cursor, Claude, Codex, Agents, plugins, and projects
- Copy prompt-ready references like `/animations` or `@nextjs`, not file paths
- Pin a floating panel beside your editor (`⌘⇧K`)
- Group skills and copy a whole stack at once
- Drag a skill straight into a prompt

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/keshav-exe/clove/releases/latest)
2. Drag Clove into Applications
3. Open it and finish the short setup

Requires macOS 26 or later. Intel and Apple Silicon.

If Gatekeeper blocks the first launch: System Settings → Privacy & Security → Open Anyway.

## Build from source

```bash
git clone git@github.com:keshav-exe/clove.git
cd clove
open Clove.xcodeproj
```

Or from the command line:

```bash
xcodebuild -scheme Clove -configuration Release -destination 'platform=macOS' build
```

Xcode 26 and the macOS 26 SDK.

To package a drag-to-Applications disk image:

```bash
./tools/MakeDMG.sh
```

Signed and notarized builds:

```bash
SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARIZE=1 ./tools/MakeDMG.sh
```

## Privacy

Skills never leave your Mac. Clove reads `SKILL.md` frontmatter and never writes to those files. Groups are saved in one JSON file inside Application Support.

Optional update checks are the only network call. No analytics. No telemetry. No account.

## License

[MIT](LICENSE)
