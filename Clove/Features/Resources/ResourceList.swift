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
        List(selection: $model.resourceSelection) {
            if !global.isEmpty {
                Section("Everywhere") {
                    ForEach(global) { resource in
                        ResourceRow(resource: resource)
                            .tag(resource.id)
                    }
                }
            }
            if !inProjects.isEmpty {
                Section("In Projects") {
                    ForEach(inProjects) { resource in
                        ResourceRow(resource: resource)
                            .tag(resource.id)
                    }
                }
            }
        }
        .listStyle(.inset)
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
