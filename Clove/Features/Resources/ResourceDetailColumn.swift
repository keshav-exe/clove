import SwiftUI

struct ResourceDetailColumn: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let resource = model.selectedResource {
                ResourceDetailView(resource: resource)
                    .id(resource.id)
            } else if case .resources(let kind) = model.section, model.resources(of: kind).isEmpty {
                // The list's own empty state already explains this; one illustration is enough.
                Color.clear
            } else {
                CalmEmptyState(
                    title: "Pick one to look inside",
                    message: "You'll see what it does, where it applies, and what it costs your agents. Most can be shared with your other agents from here."
                ) {
                    if case .resources(let kind) = model.section {
                        ResourceArt(kind: kind)
                    }
                }
            }
        }
    }
}
