import SwiftUI

struct CleanupSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label("Cleanup", systemImage: "leaf")
            .symbolRenderingMode(.hierarchical)
            .badge(badge)
            .tag(SidebarItem.cleanup)
    }

    private var badge: Text? {
        let count = model.cleanupCandidates.count
        return count == 0 ? nil : Text(count, format: .number)
    }
}
