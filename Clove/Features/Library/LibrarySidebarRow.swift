import SwiftUI

struct LibrarySidebarRow: View {
    @Environment(AppModel.self) private var model
    let filter: LibraryFilter
    /// A colour of its own, like a source's. Nil follows the sidebar, which
    /// turns the icon white on the selection instead of accent-on-accent.
    var tint: Color?

    var body: some View {
        Label {
            Text(filter.title)
                .lineLimit(1)
        } icon: {
            if let tint {
                Image(systemName: filter.symbolName)
                    .foregroundStyle(tint)
            } else {
                Image(systemName: filter.symbolName)
            }
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
