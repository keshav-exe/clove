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
            IconTile(systemImage: filter.symbolName, tint: tint, size: 17)
        }
        .badge(model.count(of: filter))
        .tag(filter)
    }
}
