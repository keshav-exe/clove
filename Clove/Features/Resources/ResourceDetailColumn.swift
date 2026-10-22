import SwiftUI

struct ResourceDetailColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let resource = model.selectedResource {
                ResourceDetailView(resource: resource)
                    .id(resource.id)
            } else {
                ContentUnavailableView(
                    "Nothing Selected",
                    systemImage: "sidebar.squares.left",
                    description: Text("Pick an item to see what it does, where it applies, and what it costs your agents.")
                )
            }
        }
        .navigationSplitViewColumnWidth(min: Metrics.detailMinWidth, ideal: 460)
    }
}
