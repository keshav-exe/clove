import SwiftUI

struct LibraryGroupMenu: View {
    @Environment(AppModel.self) private var model
    let group: String

    var body: some View {
        Button("Copy Group", systemImage: "doc.on.doc", action: copy)
        Button(
            model.isGroupPinned(group) ? "Unpin from Panel" : "Pin to Panel",
            systemImage: "pin",
            action: togglePin
        )
        Divider()
        Button("Delete Group", systemImage: "trash", role: .destructive, action: delete)
    }

    private func copy() {
        model.copyGroup(group)
    }

    private func togglePin() {
        model.togglePinGroup(group)
    }

    private func delete() {
        model.deleteGroup(group)
    }
}
