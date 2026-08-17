import SwiftUI

struct EmptySkillsView: View {
    let mode: EmptySkillsMode
    var onRefresh: (() -> Void)?

    var body: some View {
        switch mode {
        case .noSkills:
            ContentUnavailableView {
                Label("No Skills Found", systemImage: "command")
            } description: {
                Text("Clove looks in your Cursor, Claude, Codex, and Agents folders, plus any project folders you add.")
            } actions: {
                if let onRefresh {
                    Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                }
            }
        case .noResults(let query):
            ContentUnavailableView.search(text: query)
        }
    }
}
