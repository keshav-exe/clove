# Product Marketing Context

*Last updated: August 17, 2026*

## Product Overview

**One-liner:** Clove is a native Mac app that finds every agent skill on your machine and lets you copy or drop them into prompts in seconds.

**What it does:** Clove scans SKILL.md files from Cursor, Claude, Codex, Agents, plugins, and your repos. It gives you a searchable library, a floating quick-access panel, tags for organization, and one-click copy of skill references like `/animations` or `@nextjs`.

**Product category:** Developer utility / prompt workflow tool (sits next to Raycast, Paste, and Cursor itself)

**Product type:** Native macOS app

**Business model:** One-time purchase via Dodo Payments ($39 list, $19.99 intro). License key per purchase, 2 Mac activations, offline grace 14 days. Direct download from store (not App Store).

## Target Audience

**Target companies:** N/A (individual developers)

**Decision-makers:** Individual engineers, designers who code, indie hackers, AI-heavy ICs

**Primary use case:** "I have 100+ skills installed across Cursor/Claude/plugins and can't remember what's where or how to reference them in a prompt."

**Jobs to be done:**
- Find the right skill fast while coding
- Copy the correct skill reference string without opening Finder
- Batch skills for complex prompts (e.g. `/ui /swiftui-pro /animations`)
- Keep skill inventory private and local

**Use cases:**
- Pin Clove beside Cursor, search, Return to copy, paste into chat
- Drag `/nextjs` into a Claude Code prompt
- Filter by a tag/group and copy all skills for a workflow at once

## Problems & Pain Points

**Core problem:** Skills are scattered across `~/.cursor`, `~/.claude`, plugins, and project folders. Referencing them in prompts requires remembering paths, names, or digging through files.

**Why alternatives fall short:**
- Finder/manual search: slow, no references, no batch copy
- Cursor's built-in skill picker: scoped to one editor, no cross-source view
- Notes/Notion lists: manual, stale, no drag-drop or reference formatting

**What it costs them:** Context switching, wrong skills attached, repeated prompt setup, abandoned skill libraries

**Emotional tension:** "I installed all these skills but never use them because discovery is broken"

## Competitive Landscape

**Direct:** Manual skill browsing in Cursor/Claude settings — no unified search, no batch copy, no cross-source view

**Secondary:** Raycast/Alfred file search — finds files, not skill references; no tag/group copy

**Indirect:** Keeping a personal markdown list of skills — high maintenance, no drag-drop

## Differentiation

**Key differentiators:**
- Reads every skill source on-device in one place
- Copies prompt-ready references (`/skill`, `@project-skill`), not file paths
- Native macOS UI: library window + pinned floating panel
- Skill data stays on-device; license checks only hit Dodo Payments

**How we do it differently:** Local filesystem scan + user tags + keyboard-first panel optimized for prompt workflows

**Why that's better:** Faster than any editor-native picker; private; works across Cursor, Claude, Codex, and plugins

**Why customers choose us:** "Finally I can actually use the skills I installed"

## Tags vs Groups (Product Decision)

**Current state:** Clove has three overlapping concepts:

| Concept | Source | Purpose today |
|---------|--------|---------------|
| **Sources** | System (Cursor, Claude, etc.) | Filter by where skill lives |
| **Tags** | User + SKILL.md frontmatter | Filter + label skills |
| **Selection** | Ephemeral | Multi-select for batch copy |

**Recommendation: Do NOT add a separate Groups entity yet.**

Tags already behave like groups when filtered:
- Filter by tag → see all skills in that set
- "Copy all" copies space-separated references for the filtered set

**Rename in UI (not in data model):**
- User-created tags → **Groups** in UI copy ("Add to group", sidebar "Groups")
- Frontmatter tags from SKILL.md → **Labels** or keep as read-only tags (author-defined, not user organization)

**Why not separate Groups:**
- Same many-to-many relationship as tags
- Duplicate mental model: "Is this a tag or a group?"
- Tags + filter + copy-all covers the batch workflow without new data

**When to add real Groups later:**
- Ordered skill stacks (sequence matters)
- One-click "copy my frontend stack" with fixed order
- Group-level notes or descriptions
- Sharing/exporting groups between machines

Until then: **tags ARE groups for copy purposes.** Ship "Copy all in group" on tag filters (done in panel).

## Licensing (Dodo Payments)

**Pricing:** $39.00 list, $19.99 introductory one-time purchase. No subscription.

**Flow:**
1. Customer buys on the Dodo payment link → receives license key by email
2. First launch → `LicenseActivationView` → activate against Dodo public license API
3. Key + instance ID stored in Keychain; validate on launch + 14-day offline grace
4. Settings → License → deactivate to free a slot when moving Macs

**Anti-sharing (realistic):**
- Activation limit: 2 Macs per key (set on the License Key entitlement + `LicenseConfiguration.activationLimit`)
- Instance-bound validation (`license_key` + `license_key_instance_id`)
- Periodic online validation; grace period prevents false lockouts on flights
- Deactivate in Settings before selling/gifting the Mac

**What we cannot prevent:** Someone sharing the `.app` + key. No Mac DRM is bulletproof outside App Store. Activation limits + online checks deter casual sharing; determined pirates will crack anything distributed as a binary.

**Store setup checklist:**
- One-time product in Dodo with a License Key entitlement attached
- Activations limit = 2, duration blank (perpetual one-time)
- Intro discount $19.99 (regular $39)
- Paste the live payment link into `LicenseConfiguration.purchaseURL`
- Gate download behind purchase (Dodo file entitlement or manual delivery after `payment.succeeded`)

## Objections

| Objection | Response |
|-----------|----------|
| "Another menu bar app?" | Optional menu bar; opens as normal Dock app. Panel is opt-in via hotkey. |
| "Is my skill data uploaded?" | Never. Skill scanning is on-device. License checks hit Dodo Payments only. |
| "Why not just use Cursor's picker?" | Clove sees Claude, Codex, plugins, and project skills too — in one search. |

**Anti-persona:** Developers with <10 skills who don't use agent prompts regularly.

## Customer Language

**How they describe the problem:**
- "I have so many skills I forget what I installed"
- "What's the slash command for this skill again?"
- "I want ui + swiftui + animations in one prompt"

**How they describe us:**
- "Spotlight for skills"
- "Skill library for my Mac"
- "Copy paste for agent skills"

**Words to use:** copy, drop, drag, reference, on-device, library, panel, group, prompt

**Words to avoid:** sync, cloud, upload, AI-powered (for the app itself), inject (use copy/drop)

**Glossary:**
| Term | Meaning |
|------|---------|
| Skill | A SKILL.md file with agent instructions |
| Reference | Prompt string like `/animations` or `@nextjs` |
| Group | User-defined tag used to batch-copy related skills |
| Source | Where the skill is installed (Cursor, Claude, etc.) |

## Brand Voice

**Tone:** Direct, engineer-to-engineer, confident but not hyped

**Style:** Short sentences. No em dashes. Native Mac vocabulary.

**Personality:** Private, fast, competent, minimal, trustworthy

## Proof Points

**Metrics:** Scans 100+ skills in sub-second on typical dev machines (local)

**Value themes:**
| Theme | Proof |
|-------|-------|
| Privacy | No network, no account, tags in local JSON |
| Speed | Hotkey panel, Return to copy, drag to drop |
| Coverage | Cursor + Claude + Codex + Agents + plugins + projects |

## Goals

**Business goal:** Become the default skill launcher for developers using AI coding agents

**Conversion action:** Install → complete onboarding → copy first skill reference into a real prompt

**Current metrics:** Pre-launch
