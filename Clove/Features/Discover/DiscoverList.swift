import SwiftUI

struct DiscoverList: View {
    @Environment(AppModel.self) private var model

    private var store: MarketplaceStore { model.marketplace }

    var body: some View {
        @Bindable var store = model.marketplace

        let skills = store.visible.value ?? []

        ListPage(selection: $store.selection, order: skills.map(\.id)) {
            PageHeader(title: "Discover", summary: "Popular skills from skills.sh. See what each one does, and whether it passed security checks, before you install it.")

            if !skills.isEmpty {
                ListSection(
                    title: store.isSearching ? "Results" : store.feed.title,
                    note: store.isSearching ? skills.count.formatted() : store.feed.subtitle
                ) {
                    if !store.isSearching {
                        Picker("List", selection: $store.feed) {
                            ForEach(DiscoverFeed.allCases) { feed in
                                Text(feed.title).tag(feed)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .controlSize(.small)
                        .fixedSize()
                    }
                } content: {
                    ForEach(skills.enumerated(), id: \.element.id) { index, skill in
                        SelectableRow(id: skill.id, selection: $store.selection) {
                            DiscoverRow(
                                skill: skill,
                                rank: store.isSearching ? nil : index + 1,
                                showsChange: store.feed == .hot && !store.isSearching,
                                isInstalled: model.isInstalled(skill)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Discover")
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
