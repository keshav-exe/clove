import SwiftUI

struct LibraryDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let entry = model.librarySelectedEntry {
                SkillDetailView(entry: entry)
            } else {
                CalmEmptyState(
                    title: "Pick a skill",
                    message: "Its description, groups, and every place it's installed show up here. Return copies its reference."
                ) {
                    SkillsArt()
                }
            }
        }
    }
}
