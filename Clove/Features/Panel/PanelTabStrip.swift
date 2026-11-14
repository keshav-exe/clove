import SwiftUI

/// The panel's only navigation: the tab's name on the left, the tabs on the
/// right. In the notch, the notch itself sits between them (`gap`); in the
/// menu bar panel they're simply apart. Everything else is a right-click away.
struct PanelTabStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.closePanel) private var closePanel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var gap: CGFloat = 0

    var body: some View {
        let tab = model.settings.currentTab

        HStack(spacing: 0) {
            TabTitle(block: tab) {
                openInClove(model, tab.destination, closePanel: closePanel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(width: gap)

            HStack(spacing: 2) {
                ForEach(Array(model.settings.panelBlocks.enumerated()), id: \.element) { index, block in
                    TabButton(block: block, isPicked: block == tab) {
                        model.settings.panelBlock = block
                    }
                    .help("\(block.title) (⌘\(index + 1))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .animation(reduceMotion ? nil : .spring(duration: 0.24, bounce: 0), value: tab)
    }
}

/// The tab's name. It takes you to the same place in Clove's window.
private struct TabTitle: View {
    let block: PanelBlock
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(block.title)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.opacity)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(isHovered ? 1 : 0)
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help("Open \(block.title) in Clove")
    }
}

private struct TabButton: View {
    let block: PanelBlock
    let isPicked: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: block.symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isPicked ? AnyShapeStyle(.primary) : AnyShapeStyle(isHovered ? .secondary : .tertiary))
                .frame(width: 28, height: 24)
                .background(Color.primary.opacity(isPicked ? 0.14 : (isHovered ? 0.07 : 0)), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(block.title)
        .accessibilityAddTraits(isPicked ? [.isSelected] : [])
    }
}
