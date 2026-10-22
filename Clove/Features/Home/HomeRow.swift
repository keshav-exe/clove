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
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Metrics.spacingS)
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(Palette.inkSecondary))
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(destination == nil && action == nil)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.5)
        }
    }

    private func open() {
        action?()
        if let destination {
            model.show(destination)
        }
    }
}
