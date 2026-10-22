import SwiftUI

struct LibrarySidebarRow: View {
    @Environment(AppModel.self) private var model
    let filter: LibraryFilter
    let tint: Color

    var body: some View {
        Label {
            Text(filter.title)
                .lineLimit(1)
        } icon: {
            Image(systemName: filter.symbolName)
                .foregroundStyle(tint)
        }
            .badge(badge)
            .tag(SidebarItem.library(filter))
    }

    /// Zero shows no badge, like the system's own sidebars.
    private var badge: Text? {
        let count = model.count(of: filter)
        return count == 0 ? nil : Text(count, format: .number)
    }
}
