import SwiftUI

/// Mockups of what each setup step is about.
struct OnboardingArt: View {
    let step: OnboardingStep

    var body: some View {
        switch step {
        case .welcome:
            SkillsArt()
        case .privacy:
            MockStack {
                MockFileCard(fileName: "CLAUDE.md", agent: ("Claude Code", .orange))
            } middle: {
                MockKeyCard(name: "GITHUB_TOKEN")
            } front: {
                MockFileCard(fileName: "SKILL.md", agent: ("On this Mac", Palette.accent), lines: ["name: review", "", ""])
            }
        case .permissions:
            MockStack {
                MockSkillCard(reference: "/animations", summary: "Copied to the clipboard.", badges: [("Copy", .gray)])
            } middle: {
                MockSkillCard(reference: "/nextjs", summary: "Dragged into a prompt.", badges: [("Drag", .gray)])
            } front: {
                MockSkillCard(reference: "/swiftui-pro", summary: "Typed into your prompt when you press Return.", badges: [("Insert", Palette.accent)])
            }
        case .folders:
            MockStack {
                MockFileCard(fileName: "~/.cursor/skills", agent: ("Cursor", .blue), lines: ["", ""])
            } middle: {
                MockFileCard(fileName: "~/Developer", agent: ("Projects", .yellow), lines: ["", ""])
            } front: {
                MockFileCard(fileName: "~/.claude/skills", agent: ("Claude Code", .orange), lines: ["animations/", "swiftui-pro/", ""])
            }
        case .features:
            MockStack {
                MockSkillCard(reference: "/copywriting", summary: "In the Marketing group.", badges: [("Marketing", .teal)])
            } middle: {
                MockSkillCard(reference: "/ui-polish", summary: "In the Design group.", badges: [("Design", .teal)])
            } front: {
                MockSkillCard(reference: "/swiftui-pro /animations", summary: "Copy a whole group at once.", badges: [("iOS", .teal)])
            }
        case .shortcut:
            MockStack {
                MockSkillCard(reference: "/review", summary: "Pinned beside your editor.", badges: [("Panel", .gray)])
            } middle: {
                MockSkillCard(reference: "/animations", summary: "Return types it into your prompt.", badges: [("Panel", .gray)])
            } front: {
                MockShortcutCard(keys: ["⌃", "⌥", "Space"], caption: "Opens the panel from any app")
            }
        }
    }
}
