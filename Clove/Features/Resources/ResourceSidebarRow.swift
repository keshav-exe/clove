import SwiftUI

struct ResourceSidebarRow: View {
    @Environment(AppModel.self) private var model
    let kind: ResourceKind

    var body: some View {
        Label(kind.title, systemImage: kind.symbolName)
            .symbolRenderingMode(.hierarchical)
            .badge(badge)
            .tag(SidebarItem.resources(kind))
    }

    private var badge: Text? {
        let count = model.resources(of: kind).count
        return count == 0 ? nil : Text(count, format: .number)
    }
}
