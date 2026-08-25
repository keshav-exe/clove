import SwiftUI

struct SourceBadgeItem: Hashable, Sendable {
    let source: SkillSource
    let detail: String?

    var title: String {
        switch source {
        case .plugin, .project:
            detail ?? source.sectionTitle
        default:
            source.sectionTitle
        }
    }
}

struct SourceBadge: View {
    let item: SourceBadgeItem

    var body: some View {
        Text(item.title)
            .font(.caption.weight(.medium))
            .foregroundStyle(item.source.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(item.source.tint.opacity(0.13), in: .capsule)
            .accessibilityLabel(item.title)
    }
}

struct SourceBadgeRow: View {
    let items: [SourceBadgeItem]

    var body: some View {
        FlowLayout(spacing: Metrics.spacingXS) {
            ForEach(items, id: \.self) { item in
                SourceBadge(item: item)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        items.map(\.title).joined(separator: ", ")
    }
}

extension CatalogEntry {
    var sourceBadges: [SourceBadgeItem] {
        var badges: [SourceBadgeItem] = []
        var seen: Set<String> = []

        for copy in copies {
            let key = copy.source.rawValue + "\u{1e}" + (copy.sourceDetail ?? "")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            badges.append(SourceBadgeItem(source: copy.source, detail: copy.sourceDetail))
        }

        return badges.sorted { $0.source < $1.source }
    }
}

#Preview {
    SourceBadgeRow(items: [
        SourceBadgeItem(source: .cursor, detail: nil),
        SourceBadgeItem(source: .claude, detail: nil),
        SourceBadgeItem(source: .codex, detail: nil),
    ])
    .padding()
}
