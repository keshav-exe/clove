import SwiftUI

/// One page with everything Clove knows about, each card a way into its section.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text("Home")
                        .font(.largeTitle.weight(.semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.ink)
                    Text(summary)
                        .font(.title3)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], spacing: 16) {
                    HomeSkillsCard()
                    HomeRunningCard()
                    HomeCleanupCard()
                    HomeContextCard()
                    HomeToolsCard()
                    HomeTrendingCard()
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.background)
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
