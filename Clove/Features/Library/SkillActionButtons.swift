import SwiftUI

/// Shared menu content for context menus and toolbars.
struct SkillActionButtons: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    var body: some View {
        Button("Copy Reference", systemImage: "doc.on.doc") {
            model.copyReference(skill)
        }
        Button("Insert into Prompt", systemImage: "text.cursor") {
            model.insert(skill)
        }
        Divider()
        Button("Open in Default Editor", systemImage: "doc.text") {
            model.open(skill)
        }
        Button("Reveal in Finder", systemImage: "folder") {
            model.reveal(skill)
        }
        Divider()
        Button("Copy Name", systemImage: "textformat") {
            model.copyName(skill)
        }
    }
}
