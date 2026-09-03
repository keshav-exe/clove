import SwiftUI

struct TagChip: View {
    let title: String
    var isActive = false
    var onSelect: () -> Void
    var onRemove: (() -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Button(title, action: onSelect)
                .buttonStyle(.plain)

            if let onRemove {
                Button("Remove \(title)", systemImage: "xmark", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .padding(.leading, 8)
        .padding(.trailing, onRemove == nil ? 8 : 4)
        .padding(.vertical, 3)
        .background(
            isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07),
            in: .capsule
        )
        .foregroundStyle(isActive ? Color.accentColor : .secondary)
        .accessibilityElement(children: .combine)
        .contextMenu {
            if let onCopy {
                Button("Copy Group", systemImage: "doc.on.doc", action: onCopy)
            }
            Button("Filter by \(title)", systemImage: "line.3.horizontal.decrease") {
                onSelect()
            }
            if let onRemove {
                Divider()
                Button("Remove from Group", systemImage: "xmark", action: onRemove)
            }
        }
    }
}
