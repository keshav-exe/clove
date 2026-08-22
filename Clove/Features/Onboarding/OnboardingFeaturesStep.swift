import SwiftUI

struct OnboardingFeaturesStep: View {
    private let highlights = [
        FeatureHighlight(
            symbolName: "folder",
            title: "Groups",
            detail: "Create groups from the sidebar, add skills from the detail view, then pin and copy them from the panel."
        ),
        FeatureHighlight(
            symbolName: "text.cursor",
            title: "Insert",
            detail: "Paste a skill reference into Cursor, Claude, VS Code, Terminal, and other apps."
        ),
        FeatureHighlight(
            symbolName: "doc.on.doc",
            title: "Copy Reference",
            detail: "Copy the skill path to your clipboard without leaving Clove."
        ),
        FeatureHighlight(
            symbolName: "folder.badge.gearshape",
            title: "Reveal in Finder",
            detail: "Jump to the skill's folder on disk."
        ),
        FeatureHighlight(
            symbolName: "arrow.up.forward.app",
            title: "Open",
            detail: "Open SKILL.md in your default editor."
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
