import SwiftUI

struct DiscoverList: View {
    @Environment(AppModel.self) private var model

    private var store: MarketplaceStore { model.marketplace }

    var body: some View {
        @Bindable var store = model.marketplace

        List(selection: $store.selection) {
            if let skills = store.visible.value {
                ForEach(skills.enumerated(), id: \.element.id) { index, skill in
                    DiscoverRow(
                        skill: skill,
                        rank: store.isSearching ? nil : index + 1,
                        showsChange: store.feed == .hot && !store.isSearching,
                        isInstalled: model.isInstalled(skill)
                    )
                    .tag(skill.id)
                }
            }
        }
        .listStyle(.inset)
        .navigationSplitViewColumnWidth(
            min: Metrics.listMinWidth,
            ideal: Metrics.listIdealWidth + 40,
            max: 460
        )
        .navigationTitle(store.isSearching ? "Search" : store.feed.title)
        .searchable(text: $store.query, prompt: "Search skills.sh")
        .overlay {
            DiscoverListStatus(state: store.visible, query: store.query, retry: reload)
        }
        .toolbar {
            ToolbarItem {
                Button("Reload", systemImage: "arrow.clockwise", action: reload)
                    .disabled(store.visible.isLoading)
                    .help("Reload from skills.sh")
            }
        }
        .task(id: store.feed) {
            await store.loadFeed(store.feed)
        }
    }

    private func reload() {
        Task { await store.loadFeed(store.feed, force: true) }
    }
}
