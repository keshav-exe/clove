import SwiftUI

/// The web system's tile: a soft card with a raised panel set 6pt into it, so
/// the corners nest (20pt outside, 14pt inside). Flat fills, a hairline ring,
/// a breath of shadow.
struct CalmCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Tile {
            content
        }
    }
}

/// A tile with an optional header on the card, above its panel.
struct Tile<Header: View, Content: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    static var cardRadius: CGFloat { 20 }
    static var panelRadius: CGFloat { 14 }
    static var inset: CGFloat { 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // Tiles side by side stretch to the tallest; on their own this is a no-op.
            content
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Palette.surface, in: .rect(cornerRadius: Self.panelRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.panelRadius, style: .continuous)
                        .strokeBorder(Palette.ring, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .padding(Self.inset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.surfaceMuted, in: .rect(cornerRadius: Self.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
                .strokeBorder(Palette.ring, lineWidth: 1)
        }
    }
}

extension Tile where Header == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        header = EmptyView()
        self.content = content()
    }
}

/// The header that sits on a tile's card: a title, a mono count or note, and
/// an optional trailing control.
struct TileHeader<Trailing: View>: View {
    let title: String
    var note: String?
    var symbol: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text(title)
                .prose(13, .medium)
                .foregroundStyle(Palette.ink)
            if let note {
                Text(note)
                    .monoLabel()
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Metrics.spacingS)
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

extension TileHeader where Trailing == EmptyView {
    init(title: String, note: String? = nil, symbol: String? = nil) {
        self.title = title
        self.note = note
        self.symbol = symbol
        trailing = EmptyView()
    }
}

/// A page's title block: a display headline, with a line of secondary copy.
struct PageHeader: View {
    let title: String
    var summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .display(28)
                .foregroundStyle(Palette.ink)
            if let summary {
                Text(summary)
                    .prose(15)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A scrolling overview page: the same margins and reading width everywhere.
struct OverviewPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                content
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: Metrics.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.background)
    }
}
