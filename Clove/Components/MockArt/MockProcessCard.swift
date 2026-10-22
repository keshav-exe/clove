import SwiftUI

/// A running process as the Running list shows it.
struct MockProcessCard: View {
    let name: String
    let detail: String
    var port: String?

    var body: some View {
        MockCard(width: 220) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        if let port {
                            Text(port)
                                .font(.caption.monospaced())
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }
}
