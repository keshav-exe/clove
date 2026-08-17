import SwiftUI

struct LibrarySidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.sidebarSelection) {
            Section("Library") {
                LibrarySidebarRow(filter: .all, tint: .accentColor)
            }

            if !model.availableSources.isEmpty {
                Section("Sources") {
                    ForEach(model.availableSources, id: \.self) { source in
                        LibrarySidebarRow(filter: .source(source), tint: source.tint)
                    }
                }
            }

            if !model.allUserFacingTags.isEmpty {
                Section("Tags") {
                    ForEach(model.allUserFacingTags, id: \.self) { tag in
                        LibrarySidebarRow(filter: .tag(tag), tint: .teal)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Metrics.sidebarMinWidth,
            ideal: Metrics.sidebarIdealWidth,
            max: 280
        )
    }
}
