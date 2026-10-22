import SwiftUI

struct MarketplaceSkillView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let skill: MarketplaceSkill

    private var detailState: Loadable<MarketplaceDetail> {
        model.marketplace.details[skill.id] ?? .loading
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.spacingXL) {
                MarketplaceSkillHeader(skill: skill, detail: detailState.value)

                switch detailState {
                case .idle, .loading:
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 120)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Load Skill", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again", action: retry)
                    }
                case .loaded(let detail):
                    MarketplaceSkillBody(detail: detail)
                }
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MarketplaceInstallBar(skill: skill, folderHint: detailState.value?.file?.folderPath)
        }
        .navigationTitle(skill.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup {
                if let repository = skill.repositoryURL {
                    Button("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right") {
                        openURL(repository)
                    }
                    .help("Open \(skill.source) on GitHub")
                }
                Button("Open on skills.sh", systemImage: "safari") {
                    openURL(skill.pageURL)
                }
                .help("Open this skill's page on skills.sh")
            }
        }
        .task {
            await model.marketplace.loadDetail(for: skill)
        }
    }

    private func retry() {
        Task { await model.marketplace.loadDetail(for: skill, force: true) }
    }
}
