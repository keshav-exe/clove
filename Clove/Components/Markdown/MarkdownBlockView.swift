import SwiftUI

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            Text(text)
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? Metrics.spacingS : Metrics.spacingXS)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(text)
                .fixedSize(horizontal: false, vertical: true)

        case .list(let items):
            MarkdownListView(items: items)

        case .quote(let text):
            Text(text)
                .foregroundStyle(.secondary)
                .padding(.leading, Metrics.spacingM)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 3)
                }

        case .code(_, let text):
            MarkdownCodeView(text: text)

        case .table(let rows):
            MarkdownTableView(rows: rows)

        case .rule:
            Divider()
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.weight(.semibold)
        case 2: .title3.weight(.semibold)
        case 3: .headline
        default: .subheadline.weight(.semibold)
        }
    }
}
