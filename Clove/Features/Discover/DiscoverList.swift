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
        .navigationTitle("Discover")
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.isSearching {
                Picker("List", selection: $store.feed) {
                    ForEach(DiscoverFeed.allCases) { feed in
                        Text(feed.title).tag(feed)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(store.feed.subtitle)
                .padding(.horizontal, Metrics.spacingL)
                .padding(.vertical, Metrics.spacingS)
            }
        }
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
