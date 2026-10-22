import SwiftUI

/// Mockups of what each kind of agent configuration looks like on disk.
struct ResourceArt: View {
    let kind: ResourceKind

    var body: some View {
        switch kind {
        case .instructions:
            MockStack {
                MockFileCard(fileName: "GEMINI.md", agent: ("Gemini", .indigo))
            } middle: {
                MockFileCard(fileName: "CLAUDE.md", agent: ("Claude Code", .orange))
            } front: {
                MockFileCard(fileName: "AGENTS.md", lines: ["## Commands", "", "## Conventions", ""])
            }
        case .rules:
            MockStack {
                MockFileCard(fileName: "testing.mdc", agent: ("Cursor", .blue), lines: ["globs: *.test.ts", ""])
            } middle: {
                MockFileCard(fileName: ".windsurfrules", agent: ("Windsurf", .teal), lines: ["", ""])
            } front: {
                MockFileCard(fileName: "style.mdc", agent: ("Cursor", .blue), lines: ["alwaysApply: true", "", ""])
            }
        case .commands:
            MockStack {
                MockSkillCard(reference: "/deploy", summary: "Ship the current branch to staging.", badges: [("Cursor", .blue)])
            } middle: {
                MockSkillCard(reference: "/fix-issue", summary: "Reads an issue and opens a fix.", badges: [("Codex", .green)])
            } front: {
                MockSkillCard(reference: "/review", summary: "Review the diff for bugs before pushing.", badges: [("Claude Code", .orange)])
            }
        case .subagents:
            MockStack {
                MockFileCard(fileName: "test-writer.md", agent: ("Cursor", .blue), lines: ["model: sonnet", ""])
            } middle: {
                MockFileCard(fileName: "debugger.md", agent: ("Claude Code", .orange), lines: ["tools: Read, Bash", ""])
            } front: {
                MockFileCard(fileName: "code-reviewer.md", agent: ("Claude Code", .orange), lines: ["Reviews diffs for bugs.", "", ""])
            }
        case .mcpServers:
            MockStack {
                MockProcessCard(name: "github", detail: "npx · Claude Code")
            } middle: {
                MockProcessCard(name: "figma", detail: "mcp.figma.com · Cursor")
            } front: {
                MockProcessCard(name: "playwright", detail: "npx @playwright/mcp · Codex")
            }
        case .hooks:
            MockStack {
                MockFileCard(fileName: "hooks.json", agent: ("Cursor", .blue), lines: ["afterFileEdit", ""])
            } middle: {
                MockFileCard(fileName: "notify", agent: ("Codex", .green), lines: ["Turn complete", ""])
            } front: {
                MockFileCard(fileName: "settings.json", agent: ("Claude Code", .orange), lines: ["PostToolUse · Edit", "prettier --write", ""])
            }
        case .permissions:
            MockStack {
                MockFileCard(fileName: "Read(.env)", agent: ("Blocked", .red), lines: [""])
            } middle: {
                MockFileCard(fileName: "Bash(git status)", agent: ("Allowed", .green), lines: [""])
            } front: {
                MockFileCard(fileName: "Bash(npm test:*)", agent: ("Allowed", .green), lines: [""])
            }
        }
    }
}
