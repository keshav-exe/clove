import SwiftUI

struct SkillsArt: View {
    var body: some View {
        MockStack {
            MockSkillCard(reference: "/animations", summary: "Easing, duration, and when not to animate.", badges: [("Cursor", .blue)])
        } middle: {
            MockSkillCard(reference: "/release-notes", summary: "Writes notes from merged pull requests.", badges: [("Codex", .green)])
        } front: {
            MockSkillCard(
                reference: "/swiftui-pro",
                summary: "Reviews SwiftUI for modern APIs and accessibility.",
                badges: [("Claude Code", .orange), ("Shared", .purple)]
            )
        }
    }
}
