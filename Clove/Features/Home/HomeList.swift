import SwiftUI

/// Home's middle column: what's worth a look right now, then what's trending.
struct HomeList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let trending = model.marketplace.feeds[.trending]?.value ?? []
        let attention = HomeAttention.items(in: model)

        List(selection: $model.homeTrendingSelection) {
            Section("Needs a Look") {
                if attention.isEmpty {
                    Label("Nothing right now", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(attention) { item in
                        Button {
                            model.show(item.destination)
                        } label: {
                            HomeAttentionRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Trending on skills.sh") {
                ForEach(Array(trending.prefix(10).enumerated()), id: \.element.id) { index, skill in
                    DiscoverRow(skill: skill, rank: index + 1, showsChange: false, isInstalled: model.isInstalled(skill))
                        .tag(skill.id)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Home")
        .onKeyPress(.escape) {
            guard model.homeTrendingSelection != nil else { return .ignored }
            model.homeTrendingSelection = nil
            return .handled
        }
    }
}

private struct HomeAttentionRow: View {
    let item: HomeAttention

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: item.symbolName)
                    .foregroundStyle(.tint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}
