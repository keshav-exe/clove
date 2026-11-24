import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Every pane is a grouped form, the way System Settings lays itself out:
/// rounded groups, a label on the left and its control on the right.
struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width, height: SettingsMetrics.height)
    }
}

enum SettingsMetrics {
    static let width: CGFloat = 620
    static let height: CGFloat = 600
}

// MARK: - Icons

/// A setting's icon: a flat tinted square holding a white symbol, like the
/// sidebar of System Settings.
struct SettingsIcon: View {
    let symbol: String
    var tint: Color = .gray
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: .rect(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Rows

/// A row's label: icon, title, and an optional line explaining it.
struct SettingsLabel: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color = .gray

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                SettingsIcon(symbol: symbol, tint: tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A label on the left, anything on the right.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color = .gray
    @ViewBuilder let trailing: Trailing

    var body: some View {
        LabeledContent {
            trailing
        } label: {
            SettingsLabel(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        }
    }
}

/// An on/off setting, as a switch on the right.
struct SettingsToggle: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color = .gray
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

/// Keys as keycaps: "⌘", "⇧", "C".
struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 11.5, weight: .medium, design: key.count > 1 ? .default : .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, key.count > 1 ? 7 : 0)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(.background, in: .rect(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(keys.joined(separator: " "))
    }
}

/// A small coloured status: "Allowed", "Found", "Connected".
struct StatusBadge: View {
    let text: String
    var tint: Color = Palette.mint

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Reordering

/// Rows you rearrange by dragging, with a grip on each. The list moves as you
/// drag, so you see where a row lands before you let go.
struct ReorderableRows<Item: Hashable & Identifiable, Row: View>: View where Item.ID: CustomStringConvertible {
    @Binding var items: [Item]
    @ViewBuilder let row: (Item) -> Row
    @State private var dragging: Item?

    var body: some View {
        ForEach(items) { item in
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                    .help("Drag to reorder")
                row(item)
            }
            .contentShape(.rect)
            .opacity(dragging == item ? 0.35 : 1)
            .onDrag {
                dragging = item
                // A drop outside the list never reaches the rows; let go anywhere and the row comes back.
                Task { @MainActor in
                    while NSEvent.pressedMouseButtons != 0 { try? await Task.sleep(for: .milliseconds(80)) }
                    dragging = nil
                }
                return NSItemProvider(object: item.id.description as NSString)
            }
            .onDrop(of: [.text], delegate: ReorderDelegate(item: item, items: $items, dragging: $dragging))
        }
    }
}

private struct ReorderDelegate<Item: Hashable>: DropDelegate {
    let item: Item
    @Binding var items: [Item]
    @Binding var dragging: Item?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = items.firstIndex(of: dragging),
              let to = items.firstIndex(of: item) else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}
