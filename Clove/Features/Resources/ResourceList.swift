import SwiftUI

/// One kind of agent configuration, grouped by where it applies.
struct ResourceList: View {
    @Environment(AppModel.self) private var model
    let kind: ResourceKind

    var body: some View {
        @Bindable var model = model
        let resources = model.filteredResources(of: kind)
        let global = resources.filter(\.scope.isGlobal)
        let inProjects = resources.filter { !$0.scope.isGlobal }

        // Two groups, not one per project: a section per repo made a dozen
        // one-row headers that buried the names people scan for.
        ListPage(selection: $model.resourceSelection, order: (global + inProjects).map(\.id)) {
            PageHeader(title: kind.title, summary: kind.subtitle)

            if !global.isEmpty {
                ListSection(title: "Everywhere", note: global.count.formatted()) {
                    ForEach(global) { resource in
                        SelectableRow(id: resource.id, selection: $model.resourceSelection) {
                            ResourceRow(resource: resource)
                        }
                    }
                }
            }
            if !inProjects.isEmpty {
                ListSection(title: "In Projects", note: inProjects.count.formatted()) {
                    ForEach(inProjects) { resource in
                        SelectableRow(id: resource.id, selection: $model.resourceSelection) {
                            ResourceRow(resource: resource)
                        }
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .searchable(text: $model.resourceQuery, prompt: "Search \(kind.title.lowercased())")
        .overlay {
            if resources.isEmpty {
                ResourceEmptyView(kind: kind, query: model.resourceQuery, isScanning: model.isScanning)
            }
        }
        .toolbar {
            if kind == .instructions {
                ToolbarItem {
                    NewInstructionsMenu()
                }
            }
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
