import SwiftUI

/// One kind of agent configuration, grouped by where it applies.
struct ResourceList: View {
    @Environment(AppModel.self) private var model
    let kind: ResourceKind

    var body: some View {
        @Bindable var model = model
        let resources = model.filteredResources(of: kind)
        let groups = Dictionary(grouping: resources, by: \.scope).sorted { $0.key < $1.key }

        List(selection: $model.resourceSelection) {
            ForEach(groups, id: \.key) { scope, items in
                Section(scope.title) {
                    ForEach(items) { resource in
                        ResourceRow(resource: resource)
                            .tag(resource.id)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationSplitViewColumnWidth(
            min: Metrics.listMinWidth,
            ideal: Metrics.listIdealWidth + 40,
            max: 460
        )
        .navigationTitle(kind.title)
        .searchable(text: $model.resourceQuery, prompt: "Search \(kind.title.lowercased())")
        .overlay {
            if resources.isEmpty {
                ResourceEmptyView(kind: kind, query: model.resourceQuery, isScanning: model.isScanning)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .disabled(model.isScanning)
                    .help("Look for changes on disk")
            }
        }
        .onChange(of: kind) {
            model.resourceSelection = nil
        }
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
