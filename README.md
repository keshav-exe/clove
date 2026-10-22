# Clove

Native Mac app for everything your AI agents load: skills, instruction files, rules, commands, subagents, MCP servers, hooks, and permissions. Find new skills on [skills.sh](https://skills.sh), see what each agent is set up with, and clean out what you don't use.

**Free and open source.** MIT license. No account. No paywall.

[Download for Mac](https://github.com/keshav-exe/clove/releases/latest) · [Website](https://www.kshv.me/clove)

<img src="docs/product-preview.png" alt="Clove quick access panel searching agent skills" width="360" />

## What it does

Skills live in `~/.cursor`, `~/.claude`, plugins, and project folders. Referencing them in a prompt means remembering a slash command or digging through Finder. Finding new ones means a browser and a terminal.

**Library**

- Scans every `SKILL.md` on your Mac: Cursor, Claude, Codex, Agents, plugins, and projects
- Search names, descriptions, and groups
- Copy prompt-ready references like `/animations` or `@nextjs`, not file paths
- Pin a floating panel beside your editor (`⌘⇧K`), or drag a skill straight into a prompt
- Group skills and copy a whole stack at once

**Discover**

- Browse the skills.sh Top, Trending, and Hot lists, or search all of them
- Read a skill's SKILL.md, highlights, and security audits before installing
- Install in one click. Clove puts one copy in `~/.agents/skills` and links it into the agents you pick, the same layout as `npx skills add`

**Agent Setup**

- Instruction files: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, and Copilot instructions, globally and in each project, with what each costs in context
- Cursor rules (`.cursor/rules/*.mdc`, `.cursorrules`), Windsurf rules, and Copilot instruction files, with when each applies
- Commands and subagents for Claude Code, Cursor, and Codex
- MCP servers from Claude Code, Cursor, Codex, Gemini, Claude Desktop, and Windsurf. Environment variables and headers show names only, never values
- Hooks from Claude Code settings, Cursor's `hooks.json`, and Codex `notify`, with a warning when a hook's script is missing
- Claude Code permission rules per project

**Clean up**

- See which skills, commands, and subagents your agents haven't used in 30 days, 90 days, or 6 months, read from Claude Code, Codex, and Cursor history on your Mac
- See what they cost: every installed skill's description loads into each agent session
- Move them to the Trash in one click, with undo
- Reclaim disk space from old agent sessions

**Manage**

- Turn a skill on or off per agent
- Check skills from skills.sh for updates and update them in place
- Move skills to the Trash, never straight to deletion

**Write**

- Edit any SKILL.md with a live preview and checks against the Agent Skills format (`⌘E`)
- Start a new skill from a guide, workflow, or review template (`⌘N`)

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

Skills never leave your Mac. Cleanup reads agent transcripts on your Mac only to find skill names, and keeps nothing but those names and dates. Clove changes skill files only when you install, edit, or remove one, and anything it replaces goes to the Trash. Groups are saved in one JSON file inside Application Support.

Clove shares `~/.agents/.skill-lock.json` with the [skills CLI](https://github.com/vercel-labs/skills), so skills installed either way show where they came from and can be updated by both.

Network calls: skills.sh and GitHub while you use Discover or install and update a skill, plus optional app update checks. Installing from Clove sends no telemetry, so those installs don't count toward the skills.sh leaderboard. No analytics. No account.

## License

[MIT](LICENSE)
