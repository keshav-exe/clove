import SwiftUI

struct PanelPinnedGroups: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.pinnedGroups.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingS) {
                    ForEach(model.pinnedGroups, id: \.self) { group in
                        pinnedChip(group)
                    }
                }
                .padding(.horizontal, Metrics.spacingM)
                .padding(.vertical, 5)
            }
        }
    }

    private func pinnedChip(_ name: String) -> some View {
        let isActive = model.activeTag?.localizedStandardCompare(name) == .orderedSame

        return Button {
            model.toggleTagFilter(name)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 9, weight: .medium))
                Text(name)
                    .lineLimit(1)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07),
                in: .capsule
            )
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Group", systemImage: "doc.on.doc") {
                model.copyGroup(name)
            }
            Button("Unpin", systemImage: "pin.slash") {
                model.unpinGroup(name)
            }
        }
        .help("Filter by \(name). Right-click for more.")
    }
}
