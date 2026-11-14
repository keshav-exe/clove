import SwiftUI

/// One line in a Home card. With a destination it opens it; a warning tints
/// the value so problems stand out without shouting.
struct HomeRow: View {
    @Environment(AppModel.self) private var model
    let label: String
    let value: String
    var destination: SidebarItem?
    var isWarning = false
    var action: (() -> Void)?

    var body: some View {
        Button(action: open) {
            HStack(spacing: Metrics.spacingS) {
                Text(label)
                    .prose(13)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Metrics.spacingS)
                Text(value)
                    .monoLabel(12)
                    .foregroundStyle(isWarning ? AnyShapeStyle(Palette.Vivid.orange) : AnyShapeStyle(Palette.inkSecondary))
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(destination == nil && action == nil)
    }

    private func open() {
        action?()
        if let destination {
            model.show(destination)
        }
    }
}
