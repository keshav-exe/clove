import SwiftUI

struct StorageSidebarRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label("Storage", systemImage: "internaldrive")
            .symbolRenderingMode(.hierarchical)
            .badge(badge)
            .tag(SidebarItem.storage)
    }

    /// What's worth clearing, once a scan has found it.
    private var badge: Text? {
        let storage = model.storage
        guard let clean = storage.recommendation else { return nil }
        return Text(StorageFormat.gb(storage.clearableBytes(for: clean)))
    }
}
