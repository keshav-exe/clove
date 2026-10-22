import SwiftUI

struct OnboardingWelcomeStep: View {
    private let highlights = [
        FeatureHighlight(
            symbolName: "magnifyingglass",
            title: "Every skill in one place",
            detail: "Search across Claude Code, Cursor, Codex, plugins, and your projects, then drop a skill into any prompt."
        ),
        FeatureHighlight(
            symbolName: "text.document",
            title: "See what your agents load",
            detail: "Instruction files, rules, MCP servers, and hooks for every agent, with what each costs in context."
        ),
        FeatureHighlight(
            symbolName: "leaf",
            title: "Clear out what you don't use",
            detail: "Find idle skills, plus the browsers and packages agents download and forget."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(highlights) { highlight in
                    FeatureHighlightRow(highlight: highlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
    }
}
