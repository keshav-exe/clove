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
        Tile {
            Button(action: open) {
                TileHeader(title: title, symbol: symbolName) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Open \(title)")
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .display(30)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text(caption)
                        .prose(13)
                        .foregroundStyle(Palette.inkSecondary)
                }

                DividedRows {
                    rows
                }
            }
        }
    }

    private func open() {
        model.show(destination)
    }
}
