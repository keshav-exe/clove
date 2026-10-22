import SwiftUI

/// A dashboard card: a title that opens its section, one headline number,
/// and a few rows that each open something more specific.
struct HomeCard<Rows: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let symbolName: String
    let value: String
    let caption: String
    let destination: SidebarItem
    @ViewBuilder let rows: Rows

    var body: some View {
        CalmCard {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: open) {
                    HStack(spacing: Metrics.spacingS) {
                        Label(title, systemImage: symbolName)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: Metrics.spacingS)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Open \(title)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }

                VStack(spacing: 0) {
                    rows
                }
            }
        }
    }

    private func open() {
        model.show(destination)
    }
}
