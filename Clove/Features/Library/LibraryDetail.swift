import SwiftUI

struct LibraryDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let entry = model.librarySelectedEntry {
                SkillDetailView(entry: entry)
            } else {
                ContentUnavailableView(
                    "No Skill Selected",
                    systemImage: "sidebar.squares.left",
                    description: Text("Pick a skill to read its description, groups, and file location.")
                )
            }
        }
        .navigationSplitViewColumnWidth(min: Metrics.detailMinWidth, ideal: 400)
    }
}
