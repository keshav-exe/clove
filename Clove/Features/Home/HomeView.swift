import SwiftUI

/// One page with everything Clove knows about, each card a way into its section.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let attention = HomeAttention.items(in: model)

        OverviewPage {
            PageHeader(title: "Home", summary: summary)

            if !attention.isEmpty {
                Tile {
                    TileHeader(title: "Needs a look", note: attention.count.formatted())
                } content: {
                    VStack(spacing: 0) {
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
    }

    private var summary: String {
        let skills = model.catalog.count
        let instructions = model.resources(of: .instructions).count
        let servers = model.resources(of: .mcpServers).count
        let agents = Set(model.allResources.map(\.agent)).subtracting([.shared])
            .sorted()
            .prefix(3)
            .map(\.title)
            .formatted(.list(type: .and))
        return "\(skills.formatted()) skills, \(instructions) instruction files, and \(servers) MCP servers"
            + (agents.isEmpty ? "." : " across \(agents).")
    }
}

/// One thing worth a look: what it is, why, and a way straight to it.
private struct HomeAttentionRow: View {
    @Environment(AppModel.self) private var model
    let item: HomeAttention

    var body: some View {
        Button {
            model.show(item.destination)
        } label: {
            HStack(spacing: Metrics.spacingM) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.accent)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
    }
}
