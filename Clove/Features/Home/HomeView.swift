import SwiftUI

/// One page with everything Clove knows about, each card a way into its section.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let attention = HomeAttention.items(in: model)

        OverviewPage {
            PageHeader(title: "Home", summary: summary)

            // The Mac first: the live instrument, the same one Storage opens with.
            StorageCard(store: model.storage, pinned: nil) { kind in
                model.storage.pinned = kind
                model.show(.storage)
            }

            if !attention.isEmpty {
                Tile {
                    TileHeader(title: "Needs a look", note: attention.count.formatted())
                } content: {
                    DividedRows {
                        ForEach(attention) { item in
                            HomeAttentionRow(item: item)
                        }
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)], spacing: 16) {
                HomeSkillsCard()
                HomeRunningCard()
                HomeCleanupCard()
                HomeContextCard()
                HomeToolsCard()
            }
        }
        .navigationTitle("Home")
        .task {
            await model.cleanup.scanIfNeeded()
        }
        .task {
            await model.cleanup.scanLeftovers()
        }
        .task {
            await model.running.refresh(known: model.knownServers)
        }
        .task {
            await model.marketplace.loadFeed(.trending)
        }
        .task {
            await model.storage.scanIfNeeded()
        }
    }

    private var summary: String {
        let skills = model.catalog.count
        let agents = Set(model.allResources.map(\.agent)).subtracting([.shared])
            .sorted()
            .prefix(3)
            .map(\.title)
            .formatted(.list(type: .and))
        let disk = model.storage.volume.map { "\(StorageFormat.gb($0.available)) free. " } ?? ""
        return disk + "\(skills.formatted()) skills" + (agents.isEmpty ? " on this Mac." : " across \(agents).")
    }
}

/// One thing worth a look: what it is, why, and a way straight to it. Items
/// fixed in System Settings carry their own button instead of a chevron.
private struct HomeAttentionRow: View {
    @Environment(AppModel.self) private var model
    let item: HomeAttention

    var body: some View {
        Button {
            if let action = item.action { action.perform() } else { model.show(item.destination) }
        } label: {
            HStack(spacing: Metrics.spacingM) {
                Image(systemName: item.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isWarning ? Palette.Vivid.orange : Palette.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .prose(13, .medium)
                        .foregroundStyle(Palette.ink)
                    Text(item.detail)
                        .prose(12)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: Metrics.spacingS)
                if let action = item.action {
                    Text(action.title)
                        .prose(12, .medium)
                        .foregroundStyle(Palette.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
