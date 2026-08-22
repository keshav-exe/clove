import SwiftUI

struct OnboardingWelcomeStep: View {
    private let highlights = [
        FeatureHighlight(
            symbolName: "magnifyingglass",
            title: "Search everything at once",
            detail: "Names, descriptions, and groups across Cursor, Claude, Codex, Agents, plugins, and projects."
        ),
        FeatureHighlight(
            symbolName: "pin",
            title: "Pin it beside your editor",
            detail: "The quick access panel floats above other apps so your list stays in view while you work."
        ),
        FeatureHighlight(
            symbolName: "folder",
            title: "Group skills your way",
            detail: "Collect related skills into groups. Pin groups to the panel and copy them all at once."
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
