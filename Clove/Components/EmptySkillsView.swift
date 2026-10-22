import SwiftUI

struct EmptySkillsView: View {
    let mode: EmptySkillsMode
    var onRefresh: (() -> Void)?

    var body: some View {
        switch mode {
        case .noSkills:
            CalmEmptyState(
                title: "No skills yet",
                message: "Skills you install in Claude Code, Cursor, Codex, or a project show up here on their own. Find some in Discover, or start one with ⌘N."
            ) {
                SkillsArt()
            }
        case .noResults(let query):
            ContentUnavailableView.search(text: query)
        }
    }
}
