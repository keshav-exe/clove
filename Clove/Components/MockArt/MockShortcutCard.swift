import SwiftUI

/// Keycaps for a shortcut, the way they'd look on the keyboard.
struct MockShortcutCard: View {
    let keys: [String]
    let caption: String

    var body: some View {
        MockCard(width: 220) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .frame(minWidth: 30, minHeight: 28)
                            .padding(.horizontal, key.count > 1 ? 8 : 0)
                            .background(Palette.surfaceMuted, in: .rect(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
                            }
                    }
                }
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
