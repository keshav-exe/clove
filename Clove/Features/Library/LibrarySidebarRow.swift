import SwiftUI

struct LibrarySidebarRow: View {
    @Environment(AppModel.self) private var model
    let filter: LibraryFilter
    let tint: Color

    var body: some View {
        Label(filter.title, systemImage: filter.symbolName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .lineLimit(1)
            .badge(model.count(of: filter))
            .tag(filter)
    }
}
