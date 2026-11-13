import SwiftUI

/// A list section as a page, like Home: a header, then tiles of rows at a
/// reading width. Picking a row opens it in the inspector; the arrow keys move
/// the pick and keep it in view.
struct ListPage<ID: Hashable, Content: View>: View {
    @Binding var selection: ID?
    /// Every row's id in on-screen order, for the arrow keys.
    let order: [ID]
    @ViewBuilder let content: Content

    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.spacingXL) {
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
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { step(1, proxy) }
            .onKeyPress(.upArrow) { step(-1, proxy) }
            .onKeyPress(.escape) {
                guard selection != nil else { return .ignored }
                selection = nil
                return .handled
            }
        }
    }

    private func step(_ delta: Int, _ proxy: ScrollViewProxy) -> KeyPress.Result {
        guard !order.isEmpty else { return .ignored }
        let current = selection.flatMap { order.firstIndex(of: $0) }
        let next = current.map { min(order.count - 1, max(0, $0 + delta)) } ?? (delta > 0 ? 0 : order.count - 1)
        selection = order[next]
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(order[next])
        }
        return .handled
    }
}

/// One group of rows: a tile whose panel holds them, edge to edge.
struct ListSection<Trailing: View, Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileHeader(title: title, note: note) { trailing }
            LazyVStack(alignment: .leading, spacing: 1) {
                content
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Palette.surface, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.ring, lineWidth: 1)
            }
        }
        .padding(6)
        .background(Palette.surfaceMuted, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.ring, lineWidth: 1)
        }
    }
}

extension ListSection where Trailing == EmptyView {
    init(title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        trailing = EmptyView()
        self.content = content()
    }
}

/// A row you can pick. Hover and selection are fills, never weight or size
/// changes, so nothing moves under the pointer.
struct SelectableRow<ID: Hashable, Content: View>: View {
    let id: ID
    @Binding var selection: ID?
    @ViewBuilder let content: Content

    @State private var isHovered = false

    private var isSelected: Bool { selection == id }

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: 10, style: .continuous))
            .contentShape(.rect(cornerRadius: 10))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onTapGesture { selection = id }
            .id(id)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = id }
    }

    private var fill: Color {
        if isSelected { return Palette.accent.opacity(0.14) }
        if isHovered { return Palette.ink.opacity(0.04) }
        return .clear
    }
}
